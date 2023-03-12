module PollenQuarto

using Pollen: Pollen, Node, Frontend, MarkdownFormat, Rewriter, children, tag
using YAML: YAML
using Configurations: Configurations, @option


include("format.jl")
include("rewriter.jl")
include("frontend.jl")
#
# TODO: Implement `frontend_rewriters`

# TODO: File watcher for _quarto.yml

# TODO: Write _quarto.yml file after build

# TODO: Implement `frontend_serve`

# TODO: Implement `frontend_setup`: create initial `_quarto.yml` and `styles.css` files

const QUARTO = "quarto"

export QuartoFrontend

function __init__()
    try
        run(`$QUARTO`)
    catch e
        if e isa Base.IOError
            @warn "Could not find `quarto` executable. Please install it from [the Quarto website](https://quarto.org/docs/get-started/)"
        end
    end
    Pollen.FRONTENDS["quarto"] = QuartoFrontend
end

end
