from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Any


class StateStore(ABC):
    @abstractmethod
    def get(self, key: str, default: Any = None) -> Any:
        raise NotImplementedError

    @abstractmethod
    def set(self, key: str, value: Any) -> None:
        raise NotImplementedError

