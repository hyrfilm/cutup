import os

from pydantic_ai.models.test import TestModel

from . import config_stub
from src.config import set_config
from src.agent_tools import create_agent


def test_agent_tools():
    set_config(config_stub.config)
    with open("a", "w") as f:
        f.writelines(
            [
                "the template bell stops\n",
                "but sound keeps coming\n",
                "out of the flowers\n",
            ]
        )
    test_model = TestModel()
    agent = create_agent(stub=True)
    result = agent.run_sync("", model=test_model)
    assert "readfile" in result.data
    assert "writefile" in result.data

    parameters = test_model.last_model_request_parameters
    assert parameters.function_tools[0].name == "readfile"
    assert parameters.function_tools[1].name == "writefile"

    try:
        os.unlink("a")
    except:
        pass
