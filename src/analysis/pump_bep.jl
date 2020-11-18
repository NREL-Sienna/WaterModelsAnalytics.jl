"""
Calculate the best-efficiency point (BEP) for the pumps in the water network. The BEP flow,
head, and power are added to the pumps' dictionaries.
"""
function calc_pump_bep!(data::Dict{String,<:Any})
    for (pump_id, pump) in data["pump"]
        q_bep = NaN

        # Calculate best efficiency point efficiencies.
        if haskey(pump, "efficiency_curve")
            eff_curve_tuples = pump["efficiency_curve"]
            eff_curve = array_from_tuples(eff_curve_tuples)
            
            # fit efficiency curve to determine q_bep and eta_bep
            A = hcat(eff_curve[:, 1].^2, eff_curve[:, 1])
            a, b = A \ eff_curve[:, 2]
            q_bep, eta_bep = -0.5*b * inv(a), -0.25*b^2 * inv(a)
        else
            # presume the single-value for efficiency is at the BEP
            eta_bep = pump["efficiency"]
        end

        # Calculate best efficiency point head gains.
        head_curve_tuples = pump["head_curve"]
        head_curve = array_from_tuples(head_curve_tuples)

        if isnan(q_bep)
            # an efficiency curve was not provided, and so we must determine q_bep from the
            # head curve
            if size(head_curve)[1] == 1
                q_bep, g_bep = head_curve[1, 1], head_curve[1, 2]
            else
                A = hcat(head_curve[:, 1].^2, ones(size(head_curve, 1)))
                c, d = A \ head_curve[:, 2]
                q_bep, g_bep = sqrt(-0.25 * d * inv(c)), 0.75 * d
            end    
        else
            if size(head_curve)[1] == 1
                # probably rare that there is an efficiency curve and single-point or no head
                # curve -- nonetheless, it is a corner case that may be worth investigating
                # because q_bep would be overdetermined, and the two values may not agree
                #q_bep_alt = head_curve[1,1]
                g_bep = head_curve[1, 2]
            else
                # we could determine q_bep from the head curve and check wether it agrees
                # with the value determined from the efficiency curve -- will presume that
                # the one from the efficiency curve is more accurate
                A = -inv(3.0) * inv(q_bep^2) * head_curve[:, 1].^2 .+ (4.0 * inv(3.0))
                g_bep = A \ head_curve[:, 2]
            end
        end
        
        # Power at the BEP (1000 and 9.80665 are density and gravity).
        p_bep = _WM._DENSITY * _WM._GRAVITY * inv(eta_bep) * g_bep * q_bep

        # Add BEP values to the pump dictionary.
        pump["q_bep"], pump["g_bep"], pump["p_bep"] = q_bep, g_bep, p_bep
    end
end
