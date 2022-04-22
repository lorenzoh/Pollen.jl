
function frontend_install(
        dir = FRONTENDDIR;
        url = "https://github.com/lorenzoh/pollenjl-frontend",
        branch = "main",
        force = false)
    #isdir(dir) || throw(ArgumentError("Expected $dir to be a valid directory"))
    force && rm(dir; recursive=true, force=true)
    if !isdir(dir)
        readchomp(Git.git(
            ["clone", url, "-b", branch, dir]
        )) |> println
    end
    cd(dir) do
        Git.git(["checkout", branch]) |> readchomp |> println
        if force || !("node_modules" in readdir(dir))
            run(`$(npm_cmd()) install`)
        end
    end
end

function frontend_loaded(dir = FRONTENDDIR)
    isdir(dir) && ("node_modules" in readdir(dir))

end

function frontend_serve(dir = FRONTENDDIR; verbose=false)
    frontend_loaded(dir) || frontend_install(dir)
    cd(dir) do
        @info "Starting frontend dev server on http://localhost:3000/dev/i"
        p = _runsafe(`$(npm_cmd()) run dev`; verbose)
        @info "Stopped frontend dev server"
        return p
    end
end


function _runsafe(cmd; verbose = true)
    p = nothing
    io = IOBuffer()
    try
        p = run(pipeline(ignorestatus(cmd); stdout=IOContext(io, :color => true)); wait = false)
        while !(Base.process_exited(p))
            sleep(0.05)
            verbose && print(String(take!(io)))
        end
    catch e
        if e isa InterruptException
            isnothing(p) || kill(p, Base.SIGINT)
            verbose && println(String(take!(io)))
        else
            print(String(take!(io)))
            rethrow()
        end
    end
    return p
end
