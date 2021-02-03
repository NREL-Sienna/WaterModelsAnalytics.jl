import PyCall

# Change that to whatever packages you need.
const PACKAGES = ["matplotlib", "networkx", "numpy", "pandas", "pygraphviz", "PyPDF2", "wntr"]

try
    # Import pip.
    PyCall.pyimport("pip")
catch
    # If pip is not found, install it.
    println("Pip not found on your sytstem. Downloading it.")
    get_pip = joinpath(dirname(@__FILE__), "get-pip.py")
    download("https://bootstrap.pypa.io/get-pip.py", get_pip)
    run(`$(PyCall.python) $get_pip --user`)
end

run(`$(PyCall.python) -m pip install --user --upgrade pip setuptools`)
run(`$(PyCall.python) -m pip install --user $(PACKAGES)`)
