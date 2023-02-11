
abstract type Frontend end

"""
    frontendrewriters(frontend::Frontend, config)

List of rewriters for `frontend`.
"""
function frontend_rewriters end

"""
    frontend_serve(frontend, builddir)
"""
function frontend_serve end

"""
    frontend_setup(TFrontend, pkgdir)

Set up configuration files for `TFrontend <: Type{Frontend}`.
"""
function frontend_setup end


"""
    frontendformat(frontend)

Default output format to use for `frontend`.
"""
function frontend_format end

"""
    frontend_builder()
"""
frontend_builder(frontend::Frontend, builddir) = FileBuilder(frontend_format(frontend), builddir)


"""
    frontend_build(frontend, builddir) -> dir

Frontend build step triggered after the `builder = frontend_builder(frontend, dir)`.
This step can call external build tools.
"""
function frontend_build end
# TODO: Abstraction for setting up GitHub Pages
# TODO: Abstraction for deploying to GitHub Pages



const FRONTENDS = Dict{String, Type{<:Frontend}}()

#=
## Sample frontend implementation

The simplest `Frontend` is `FileFrontend` which simply renders every file out
using a `Format`, without applying any other transformations.
=#

struct FileFrontend <: Frontend
    format::Format
end

# We register the frontend with a key (`"files"``) so that it can be used by configuring
# `pollen.yml`, by adding the key-value pair `frontend: files`.

FRONTENDS["files"] = FileFrontend

# The configuration for `FileFrontend` has just one key that determines the output format
# by specifying the file extension. [`extensionformat`](#) is then used to detect the format.

default_frontend_config(::Type{FileFrontend}) = Dict(
    "filetype" => "md"
)


FileFrontend(config::Dict) = FileFrontend(
    extensionformat(Val(Symbol(config["files"]["filetype"]))))

# Extension points are basic. `frontend_serve` starts a file server using
# [LiveServer.jl](https://github.com/tlienart/LiveServer.jl).

frontend_rewriters(::FileFrontend) = Rewriter[]

frontend_format(frontend::FileFrontend) = frontend.format

frontend_serve(::FileFrontend, dir) = LiveServer.serve(dir=dir)

function frontend_build(::FileFrontend, dir) end
