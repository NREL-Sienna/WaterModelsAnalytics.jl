# TODO:
# - make sure that single-point head curves are managed OK

"""
Plot the normalized pump curves for the pumps in a network
"""
function plot_pumps(pumps::Dict{String,Any})
    m = 50
    Qhat = Array(range(0.0, 2.0, length=m))
    etahat = -Qhat.^2 .+ 2*Qhat
    Ghat = -1/3*Qhat.^2 .+ 4/3
    Phat = 1/3*Qhat .+ 2/3

    p1 = Plots.plot()
    p2 = Plots.plot()
    p3 = Plots.plot()
    plotargs = Dict(:lt=>:scatter, :shape=>:circle, :ms=>6, :msc=>:auto)
    for (key,pump) in pumps
        #println(pump["name"])
        Qbep = pump["q_bep"]
        Gbep = pump["g_bep"]
        Pbep = pump["P_bep"] # inconsistent capitilization...
        etabep = 1000.0 * 9.80665 * inv(Pbep) * Gbep * Qbep
        head = _WM.array_from_tuples(pump["head_curve"])
        eff_is_curve = haskey(pump, "efficiency_curve")
        if eff_is_curve
            eff = _WM.array_from_tuples(pump["efficiency_curve"])
            qmin = max(head[1,1], eff[1,1])/Qbep
            qmax = min(head[end,1], eff[end,1])/Qbep
        else
            eff = pump["efficiency"]
            qmin = head[1,1]/Qbep
            qmax = head[end,1]/Qbep
        end
        # create power curves by linear interpolation of head and eff curves
        headitp = _ITP.LinearInterpolation(head[:,1]/Qbep, head[:,2]/Gbep)
        if eff_is_curve
            effitp = _ITP.LinearInterpolation(eff[:,1]/Qbep, eff[:,2]/etabep)
        else
            effitp(x::Float64) = eff
            effitp(x::Array{Float64}) = eff*ones(size(x))
        end
        q = Array(range(qmin, stop=qmax, length=7)) # can change number of points here
        pow = headitp(q).*q./effitp(q)

        Plots.plot!(p1, head[:,1]/Qbep, head[:,2]/Gbep, label=""; plotargs...)
        if eff_is_curve
            Plots.plot!(p2, eff[:,1]/Qbep, eff[:,2]/etabep, label=pump["name"]; plotargs...)
        else
            Plots.plot!(p2, (1, 1), label=pump["name"]; plotargs...)
        end
        Plots.plot!(p3, q, pow, label="", ylims=(0,2); plotargs...)
    end
     # use legend=:none ?? then will not need empty label keys above
    Plots.plot!(p1, Qhat, Ghat, lc=:black, lw=2, label="", ylabel=L"\hat{G}")
    Plots.plot!(p2, Qhat, etahat, lc=:black, lw=2, label="", ylabel=L"\hat{\eta}",
                legend=:bottom)
    Plots.plot!(p3, Qhat, Phat, lc=:black, lw=2, label="", xlabel=L"\hat{Q}",
                ylabel=L"\hat{P}")
    #height = 400  # default is 600 x 400 (w x h)
    #width = 4*height
    width = 400
    height = width*4/6*3
    ## this command must be last to display the plot?
    #Plots.plot(p1, p2, p3, size=(width,height), layout=(1,3))
    Plots.plot(p1, p2, p3, size=(width,height), layout=(3,1)) # orient 3x1 instead to share
end 