#=
from_config
from_project_config
default_config
canonicalize_config
from_configs

merge_configs(T, c1, c2) = merge_configs(
    canonicalize_config(T, c1),
    canonicalize_config(T, c2),
)

struct Config
    fields
end

T



=#
