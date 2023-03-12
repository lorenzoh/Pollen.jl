
abstract type Frontend end

"""
    frontend_rewriter_entries(frontend::Frontend, config)

List of rewriters for `frontend`.
"""
function frontend_rewriter_entries(::AbstractConfig)
    RewriterEntry[]
end

function with_frontend_rewriters(config_frontend::AbstractConfig, rewriter_entries)
    vcat(rewriter_entries, frontend_rewriter_entries(config_frontend))
end
with_frontend_rewriters(::Nothing, rewriter_entries) = rewriter_entries


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
    frontend_build(frontend, project, dir[, docids])
"""
function frontend_build end


"""
    frontend_build(frontend, builddir) -> dir

Frontend build step triggered after the `builder = frontend_builder(frontend, dir)`.
This step can call external build tools.
"""
function frontend_build end



# TODO: Abstraction for setting up GitHub Pages
# TODO: Abstraction for deploying to GitHub Pages


# So that other packages can register new `Frontend`s under a configuration key, we define
# a global constant where they can add an entry. See below for how this is done.

const FRONTENDS = Dict{String, Type{<:Frontend}}()

#=
## Sample frontend implementation

The simplest `Frontend` is `FileFrontend`, which simply renders every file out
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

@option struct ConfigFileFrontend <: AbstractConfig
    filetype::String = "md"
end
configtype(::Type{FileFrontend}) = ConfigFileFrontend


function from_config(config::ConfigFileFrontend)
    format = extensionformat(Val(Symbol(config.filetype)))
    FileFrontend(format)
end

# Extension points are basic. `frontend_serve` starts a file server using
# [LiveServer.jl](https://github.com/tlienart/LiveServer.jl).

frontend_rewriters(::FileFrontend) = Rewriter[]

frontend_serve(::FileFrontend, dir) = LiveServer.serve(dir=dir)

function frontend_build(frontend::FileFrontend, project, dir::String, docids = Set(keys(project.sources)))
    builder = FileBuilder(frontend.format, dir)
    build(project, builder, docids)
end
