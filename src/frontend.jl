
function frontend_install(dir = FRONTENDDIR;
                          npm = nodejs_cmd(),
                          url = "https://github.com/lorenzoh/pollenjl-frontend",
                          branch = "main",
                          force = false)
    force && rm(dir; recursive = true, force = true)
    if !isdir(joinpath(dir, ".git"))
        @info "Cloning Pollen.jl frontend code from $url..."
        readchomp(Git.git(["clone", url, "-b", branch, dir])) |> println
    end
    cd(dir) do
        Git.git(["checkout", branch]) |> readchomp |> println
        if force || !("node_modules" in readdir(dir))
            @info "Installing Pollen.jl frontend dependencies..."
            run(`$npm install`)
        end
    end
end

function is_frontend_loaded(dir = FRONTENDDIR)
    isdir(dir) && ("node_modules" in readdir(dir))
end

function frontend_serve(dir = FRONTENDDIR; verbose = false, npm = nodejs_cmd())
    is_frontend_loaded(dir) || frontend_install(dir)
    cd(dir) do
        @info "Starting frontend dev server at http://localhost:5173"
        p = _runsafe(`$npm run dev`; verbose)
        @info "Stopped frontend dev server"
        return p
    end
end

# ### Utilties

function _runsafe(cmd; verbose = true)
    p = nothing
    io = IOBuffer()
    io_err = IOBuffer()
    try
        p = run(pipeline(ignorestatus(cmd); stderr = io_err,
                         stdout = IOContext(io, :color => true)); wait = false)
        while !(Base.process_exited(p))
            sleep(0.05)
            verbose && print(String(take!(io)))
        end
    catch e
        if e isa InterruptException
            isnothing(p) || kill(p, Base.SIGINT)
            verbose && println(String(take!(io)))
        else
            rethrow()
        end
    end
    return p
end
