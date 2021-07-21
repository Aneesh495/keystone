"""
Keystone Client Data Transfer Objects
"""

from dataclasses import dataclass, field
from typing import Dict, Any, List, Optional


@dataclass
class HealthStatus:
    status: str
    version: str
    subsystems: Dict[str, Any] = field(default_factory=dict)


@dataclass
class ParseResult:
    success: bool
    ast: Dict[str, Any] = field(default_factory=dict)
    errors: List[str] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)


@dataclass
class TransactionRecord:
    transaction_id: str
    timestamp: str
    sender_id: str
    receiver_id: str
    protocol: str
    document_type: str
    status: str
    payload_hash: str
