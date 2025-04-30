from collections.abc import Iterable
from typing import Any, Callable, Optional


def join_items(
        items: Iterable[Any],
        sep: str = ", ",
        *,
        sort: bool = True,
        key: Optional[Callable[[Any], Any]] = None,
) -> str:
    """
    Convert *items* to a single string separated by *sep*.

    Parameters
    ----------
    items : iterable
        Any iterable of values. Non-string elements are cast with str().
    sep : str, default ", "
        Delimiter placed between elements.
    sort : bool, default True
        Sort items to ensure deterministic output (helpful for sets).
    key : callable, optional
        Key function forwarded to `sorted`; ignored if sort=False.
    """
    iterable = sorted(items, key=key) if sort else items
    return sep.join(map(str, iterable))
