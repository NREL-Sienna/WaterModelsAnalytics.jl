import PyCall


# Change that to whatever packages you need.
const PACKAGES = ["pygraphviz", "PyPDF2", "wntr"]

try
    for package in PACKAGES
        PyCall.pyimport(package)
    end
catch
    @warn("Python `pip` will be used to install Python modules.")
    try
        # Import pip.
        PyCall.pyimport("pip")
    catch
        # If pip is not found, install it.
        @warn("Pip not found on your sytstem. Downloading it.")
        get_pip = joinpath(dirname(@__FILE__), "get-pip.py")
        download("https://bootstrap.pypa.io/get-pip.py", get_pip)
        run(`$(PyCall.python) $get_pip --user`)
    end
    
    # don't upgrade... let pip work with whatever exists or install new
    # run(`$(PyCall.python) -m pip install --user --upgrade pip setuptools`)
    run(`$(PyCall.python) -m pip install --user $(PACKAGES)`)
end
