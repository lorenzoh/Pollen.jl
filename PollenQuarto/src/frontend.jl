struct QuartoFrontend <: Frontend
    config::Dict
end

Pollen.FRONTENDS["quarto"] = QuartoFrontend


@option struct ConfigQuartoFrontend <: Pollen.AbstractConfig
    # The Quarto configuration that will be written to pollen.yml
    config::Dict = Dict{String, Any}()
end
Pollen.configtype(::Type{QuartoFrontend}) = ConfigQuartoFrontend

function Pollen.from_project_config(
        ::Type{ConfigQuartoFrontend},
        config_project::Pollen.ConfigProject,
        values::Dict = Dict{String, Any}())
    # load default config
    config = default_quarto_config(config_project)

    # merge values in Pollen project configuration
    config = Pollen.mergerec(config, values)

    # search for _quarto.yml file and merge in values
    quartofile = joinpath(config_project.dir, "_quarto.yml")
    if isfile(quartofile)
        config = Pollen.mergerec(quartoconfig, YAML.load_file(quartofile))
    end

    return ConfigQuartoFrontend(config)
end

Pollen.from_config(c::ConfigQuartoFrontend) = QuartoFrontend(c.config)

function Pollen.frontend_rewriter_entries(config_frontend::ConfigQuartoFrontend)
    # TODO: Add copying of assets
    return [
        Pollen.RewriterEntry("quarto", PrepareQuarto, true, [], Dict{String, Any}()),
    ]
end

function Pollen.frontend_build(frontend::QuartoFrontend, project, dir, docids)
    Pollen.build(Pollen.FileBuilder(QuartoMarkdownFormat(), dir), project, docids)
    YAML.write_file(joinpath(dir, "_quarto.yml"), frontend.config)
    # TODO: add redirect page
    # TODO: copy stylesheets and other resources
end


# ## Configuration loading

function default_quarto_config(config::Pollen.ConfigProject)
    return Dict(
        "project" => Dict(
            "type" => "website",
            "render" => ["*.md", "*.qmd", "*.ipynb", "**/README.md"],
        ),
        "website" => Dict(
            "title" => config.title,
            "search" => Dict(
                "location" => "sidebar",
                "type" => "overlay",
            ),
            "sidebar" => Dict(
                "style" => "docked",
                "contents" => _to_quarto_toc(config.contents),
            )
        ),
        "format" => Dict(
            "html" => Dict(
                "theme" => "cosmo",
                "toc" => true
            )
        )
    )
end

function _to_quarto_toc(toc)
    quartotoc = Any[]
    for (k, v) in toc
        if v isa String
            push!(quartotoc, Dict("href" => "$v", "text" => k))
        else
            push!(quartotoc, Dict("section" => k, "contents" => _to_quarto_toc(v)))
        end
    end
    return quartotoc
end

function load_quarto_config(config::Dict)
    quartoconfig = default_quarto_config(config)
    quartofile = joinpath(config["package"]["dir"], "_quarto.yml")
    if isfile(quartofile)
        quartoconfig = Pollen.mergeconfigs(quartoconfig, YAML.load_file(quartofile))
    end
    return quartoconfig
end
