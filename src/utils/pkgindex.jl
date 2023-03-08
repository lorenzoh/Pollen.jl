#=
So that we can load `Rewriter`s from configuration with `from_config`, this file contains
some helpers for instantiating `PackageIndex`es from configuration. This will be used by
many rewriters that need access to a configurable package index.
=#

default_config(::typeof(PackageIndex)) = Dict(
    "packages" => String[],
    "projects" => [Base.active_project()],
    "recurse" => 0,
    "verbose" => true,
    "cache" => true,
)

default_config_project(T, project_config) = default_config(T)
function default_config_project(::typeof(PackageIndex), project_config)
    config = default_config(PackageIndex)

    # If the project is a package directory, add that package to the package list
    # and add the package directory as an environment to check for packages.
    pkg_config = get(project_config, "package", nothing)
    if pkg_config !== nothing
        push!(config["projects"], pkg_config["dir"])
        push!(config["packages"], pkg_config["name"])
    end

    return config
end

canonicalize_config(T, config::Dict) = config
canonicalize_config(T, config::Bool) = config ? default_config(T) : config
canonicalize_config(::typeof(PackageIndex), config::Vector) = Dict("packages" => config)

with_default_config(T, config) =
    merge_configs(default_config(T), canonicalize_config(T, config))

from_project_config(T, config, project_config) =
    from_config(
        T,
        merge_configs(
            default_config_project(T, project_config),
            canonicalize_config(T, config)))

function from_config(::typeof(PackageIndex), config)
    # TODO: validate that "projects" are valid Julia projects
    config = with_default_config(PackageIndex, config)

    packages = unique(config["packages"])
    available_packages = reduce(vcat, map(ModuleInfo.get_project_packages, config["projects"]))
    unavailable_packages = filter(!in(available_packages), packages)
    if !isempty(unavailable_packages)
        throw(ArgumentError("""When creating a package index from a configuration, \
                could not find the following packages in the availble Julia projects. \
                Make sure that the packages are either a direct dependency of or defined \
                by any of the Julia projects:
                - Missing packages: $unavailable_packages
                - Julia projects: $(config["projects"]) """))
    end

    modules::Vector{Module} = unique(reduce(vcat, map(config["projects"]) do proj
        proj_module = ModuleInfo.load_project_module(proj)
        # For packages, return the package module
        Symbol(proj_module) !== :Main && return [proj_module]
        # For environments, load all modules that are in packages:
        return ModuleInfo.load_project_dependencies(ModuleInfo.projectfile(proj_module); packages)
    end))
    return PackageIndex(modules; recurse=1, packages=packages)
end
