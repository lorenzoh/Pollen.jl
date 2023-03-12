#=
So that we can load `Rewriter`s from configuration with `from_config`, this file contains
some helpers for instantiating `PackageIndex`es from configuration. This will be used by
many rewriters that need access to a configurable package index.
=#
@option struct ConfigPackageIndex <: AbstractConfig
    packages::Vector{String} = String[]
    projects::Vector{String} = String[]
    recurse::Int = 0
    verbose::Bool = true
    cache::Bool = true
end
configtype(::Type{PackageIndex}) = ConfigPackageIndex


function from_project_config(::Type{ConfigPackageIndex}, project_config::ConfigProject, values::Dict)
    if !isnothing(project_config.package)
        # Append package name and project/environment to index from
        unique!(push!(get!(values, "projects", String[]), project_config.package.dir))
        unique!(push!(get!(values, "packages", String[]), project_config.package.name))
    end
    return from_dict(ConfigPackageIndex, values)
end


function from_config(config::ConfigPackageIndex)
    # TODO: validate that "projects" are valid Julia projects
    # TODO: make recurse work as expected
    packages = unique(config.packages)
    available_packages = reduce(
        vcat, map(ModuleInfo.get_project_packages, config.projects), init=String[])
    unavailable_packages = filter(!in(available_packages), packages)
    if !isempty(unavailable_packages)
        throw(ArgumentError("""When creating a package index from a configuration, \
                could not find the following packages in the availble Julia projects. \
                Make sure that the packages are either a direct dependency of or defined \
                by any of the Julia projects:
                - Missing packages: $unavailable_packages
                - Julia projects: $(config.projects) """))
    end

    modules::Vector{Module} = unique(reduce(vcat, map(config.projects) do proj
        proj_module = ModuleInfo.load_project_module(proj)
        # For packages, return the package module
        Symbol(proj_module) !== :Main && return [proj_module]
        # For environments, load all modules that are in packages:
        return ModuleInfo.load_project_dependencies(ModuleInfo.projectfile(proj_module); packages)
    end; init=Module[]))
    return PackageIndex(modules; recurse=max(1, config.recurse), packages=packages)
end


@testset "PackageIndex" begin
    @test from_project_config(ConfigPackageIndex, ConfigProject()).recurse == 0

    @testset "Include package configuration" begin
        project_config = load_project_config(pkgdir(@__MODULE__))
        pkgindex_config = from_project_config(ConfigPackageIndex, project_config)
        @test !isempty(pkgindex_config.projects)
        @test !isempty(pkgindex_config.packages)
    end
end
