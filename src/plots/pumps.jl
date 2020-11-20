"""
Plot the normalized pump curves for the pumps in a network. Displays the plot on the screen
by default. Use keywords `screen` and `savepath` to control whether to display and/or save
to file.
"""
function plot_pumps(pumps::Dict{String,Any}; normalized=true, screen=true, reuse=true,
                    savepath=nothing)
    m = 50
    Qhat = Array(range(0.0, 2.0, length=m))
    etahat = -Qhat.^2 .+ 2*Qhat
    Ghat = -1/3*Qhat.^2 .+ 4/3
    Phat = 1/3*Qhat .+ 2/3

    p1 = Plots.plot()
    p2 = Plots.plot()
    p3 = Plots.plot()
    plotargs = Dict(:lt=>:scatter, :shape=>:circle, :ms=>6, :msc=>:auto)
    for (i,(key,pump)) in enumerate(pumps)
        Qbep = pump["q_bep"]
        Gbep = pump["g_bep"]
        Pbep = pump["p_bep"] 
        etabep = _WM._DENSITY * _WM._GRAVITY * inv(Pbep) * Gbep * Qbep
        head = array_from_tuples(pump["head_curve"])
        eff_is_curve = haskey(pump, "efficiency_curve")
        if eff_is_curve
            eff = array_from_tuples(pump["efficiency_curve"])
            qmin = max(head[1,1], eff[1,1])/Qbep
            qmax = min(head[end,1], eff[end,1])/Qbep
        else
            eff = pump["efficiency"]
            qmin = head[1,1]/Qbep
            qmax = head[end,1]/Qbep
        end

        # create power curves by linear interpolation of head and eff curves
        if size(head)[1] > 1
            headitp = _ITP.LinearInterpolation(head[:,1]/Qbep, head[:,2]/Gbep)
        else
            headitp(x::Float64) = head[1,2]
            headitp(x::Array{Float64}) = head[1,2]*ones(size(x))
        end
        if eff_is_curve
            effitp = _ITP.LinearInterpolation(eff[:,1]/Qbep, eff[:,2]/etabep)
        else
            effitp(x::Float64) = eff
            effitp(x::Array{Float64}) = eff*ones(size(x))
        end
        if qmin==qmax
            q = [1]
            pow = [1]
        else
            q = Array(range(qmin, stop=qmax, length=7)) # can change number of points here
            pow = headitp(q).*q./effitp(q)
        end

        # plot head curve
        if normalized
            Plots.plot!(p1, head[:,1]/Qbep, head[:,2]/Gbep, mc=i; plotargs...)
        else
            Plots.plot!(p1, head[:,1], head[:,2], mc=i; plotargs...)
            Plots.plot!(p1, Qbep*Qhat, Gbep*Ghat, lc=i, lw=2, label="") # fit curve
        end
        #plot efficiency curve
        if eff_is_curve
            if normalized
                Plots.plot!(p2, eff[:,1]/Qbep, eff[:,2]/etabep, label=pump["name"], mc=i;
                            plotargs...)
            else
                Plots.plot!(p2, eff[:,1], eff[:,2], label=pump["name"], mc=i; plotargs...)
            end
        else # plot the single point
            if normalized
                Plots.plot!(p2, (1, 1), label=pump["name"], mc=i; plotargs...)
            else
                Plots.plot!(p2, (Qbep, etabep), label=pump["name"], mc=i; plotargs...)
            end
        end
        if !normalized # fit curve
            Plots.plot!(p2, Qbep*Qhat, etabep*etahat, lc=i, lw=2, label="")
        end
        # plot power curve
        if normalized
            Plots.plot!(p3, q, pow, ylims=(0,2), mc=i; plotargs...)
        else
            Plots.plot!(p3, q*Qbep, pow*Pbep, mc=i; plotargs...)
            Plots.plot!(p3, Qbep*Qhat, Pbep*Phat, lc=i, lw=2, label="") # fit curve
        end
    end
    if normalized
        # plot normalized fit curves and add axes labels and legend
        Plots.plot!(p1, Qhat, Ghat, lc=:black, lw=2, label="", ylabel=L"\hat{G}",
                    legend=:none)
        Plots.plot!(p2, Qhat, etahat, lc=:black, lw=2, label="", ylabel=L"\hat{\eta}",
                    legend=:bottom)
        Plots.plot!(p3, Qhat, Phat, lc=:black, lw=2, label="", xlabel=L"\hat{Q}",
                    ylabel=L"\hat{P}", legend=:none)
    else
        # add axes labels and legend (not-normalized fit curves already plotted)
        Plots.plot!(p1, ylabel=L"G", legend=:none)
        Plots.plot!(p2, ylabel=L"\eta", legend=:bottom)
        Plots.plot!(p3, xlabel=L"Q", ylabel=L"P", legend=:none)
    end
    
    width = 400
    height = width*4/6*3
    pfig = Plots.plot(p1, p2, p3, size=(width,height), layout=(3,1), reuse=reuse);
    # display on the screen and/or save
    screen ? display(pfig) : nothing
    savepath != nothing ? Plots.savefig(pfig, savepath) : nothing
end 
