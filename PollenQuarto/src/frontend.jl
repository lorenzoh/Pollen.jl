struct QuartoFrontend <: Frontend
    pollenconfig::Dict
    quartoconfig::Dict
end

Pollen.FRONTENDS["quarto"] = QuartoFrontend

QuartoFrontend(config::Dict) = QuartoFrontend(config, load_quarto_config(config))

Pollen.frontend_format(::QuartoFrontend) = MarkdownFormat()

function Pollen.frontend_rewriters(frontend::QuartoFrontend)
    return Rewriter[
        ConfigureQuarto(frontend.quartoconfig)
    ]
end

function Pollen.frontend_build(frontend::QuartoFrontend, dir::String)

end


# ## Configuration loading

function default_quarto_config(config)
    return Dict(
        "project" => Dict(
            "type" => "website",
            "render" => ["*.md", "*.qmd", "*.ipynb"],
        ),
        "website" => Dict(
            "title" => config["title"],
            "search" => Dict(
                "location" => "sidebar",
                "type" => "overlay",
            ),
            "sidebar" => Dict(
                "style" => "docked",
                "contents" => _to_quarto_toc(config["contents"]),
            )
        ),
        "format" => Dict(
            "html" => Dict(
                "theme" => "cosmo",
                "css" => "styles.css",
                "toc" => true
            )
        )
    )
end

function _to_quarto_toc(toc)
    quartotoc = Any[]
    for (k, v) in toc
        if v isa String
            push!(quartotoc, Dict("href" => v, "text" => k))
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
