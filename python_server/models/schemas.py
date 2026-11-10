from pydantic import BaseModel, Field
from typing import Optional

# Length caps: these strings go straight into LLM prompts on a public server.


class ScrapeRequest(BaseModel):
    topic: str = Field(min_length=1, max_length=100)


class RAGRequest(BaseModel):
    prompt: str = Field(min_length=1, max_length=2000)
    topic: Optional[str] = Field(default=None, max_length=100)
    # Set by the in-game bot: answer as a spoiler-free guide for this riddle.
    riddle: Optional[str] = Field(default=None, max_length=1000)


class RiddleRequest(BaseModel):
    topic: str = Field(min_length=1, max_length=100)
    difficulty: str = Field(default="MEDIUM", max_length=20)


class EvaluateRequest(BaseModel):
    question_title: str = Field(max_length=200)
    question_desc: str = Field(max_length=2000)
    expected_output: str = Field(max_length=2000)
    user_code: str = Field(max_length=8000)
