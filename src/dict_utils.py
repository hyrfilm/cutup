def has_all(d: dict, *keys: str) -> bool:
    return all(key in d for key in keys)
