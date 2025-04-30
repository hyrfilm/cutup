from library import *
from pathlib import Path

model = "TestEventLog"

# TODO: This is incredibly tedious & weird. The whole idea
# TODO: of a "repo" parameter is stupid and clumsy.
# TODO: Refactor to provide some other kind of conceptualization 
# TODO: eg. input_dir & outdir_dir?!
# TODO: (input_dir == script_dir by default? Always provide
# TODO: the other parameters?)
repo = Path(get_env_var("repo"))
backend_dir = "backend"
api_dir = "backend/api"
files = search_files(model, repo.joinpath(api_dir))
dbFacade = f"backend/api/utils/db/dbFacade.ts"

for src_file in files:
    instructions = [
        f"Read the file path://@(repo)/{dbFacade} carefully ",
        f"including the comments describing its coding conventions. ",
        f"Its purpose is to wrap calls to the Waterline models in order ",
        f"to replace Waterline in the future without needing to change the facade interface."
        f"The waterline model definition can be found at path://@(repo)/backend/api/models/{model}.js",
        f"Read the file path://@(repo)/{src_file} and make sure that calls to {model} are replaced by call to the facade.",
        f"If a suitable function already exists call it, otherwise create it."
        f"The functions that Waterline models supports are: create, update, updateOne, find, findOne, destroy, destroyOne, count"
        f"Finally write those changes to the affected files."
    ]

    prompt(instructions)
