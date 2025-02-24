import os
from pprint import pprint

from pydantic_ai.models.test import TestModel

from agent_tools import agent


def test_agent_tools():
    with open("a", "w") as f:
        f.writelines(
            [
                "the template bell stops\n",
                "but sound keeps coming\n",
                "out of the flowers\n",
            ]
        )
    test_model = TestModel()
    result = agent.run_sync("", model=test_model)
    assert "readfile" in result.data
    assert "writefile" in result.data

    assert test_model.last_model_request_parameters.function_tools[0].name == "readfile"
    assert (
        test_model.last_model_request_parameters.function_tools[1].name == "writefile"
    )

    try:
        os.unlink("a")
    except:
        pass
