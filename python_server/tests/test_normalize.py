"""Run: python -m pytest tests  (or: python tests/test_normalize.py)"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from services.llm import normalize_riddle  # noqa: E402

GOOD = {
    "riddle": "I repeat until false. What am I?",
    "options": ["Loop", "Array", "Class", "Stack"],
    "solution": "loop",
    "hints": ["h1", "h2", "h3", "h4"],
    "fact_reference": "Loops repeat.",
}


def test_valid_riddle_keeps_option_casing():
    r = normalize_riddle(dict(GOOD))
    assert r["solution"] == "Loop" and "Loop" in r["options"] and len(r["options"]) == 4


def test_missing_solution_is_inserted_into_options():
    r = normalize_riddle(dict(GOOD, options=["Array", "Class", "Stack", "Queue"]))
    assert r["solution"] == "loop" and "loop" in r["options"] and len(r["options"]) == 4


def test_answer_survives_when_llm_returns_too_many_options():
    for _ in range(50):  # shuffling is random; the answer must survive every time
        r = normalize_riddle(dict(GOOD, options=["Array", "Class", "Stack", "Queue", "Heap", "Loop"]))
        assert len(r["options"]) == 4 and r["solution"] in r["options"]


def test_short_hint_list_is_padded():
    assert len(normalize_riddle(dict(GOOD, hints=["only one"]))["hints"]) == 4


def test_multi_word_or_long_answers_are_rejected():
    for bad in ["two words", "", "averyveryverylongword"]:
        try:
            normalize_riddle(dict(GOOD, solution=bad))
        except ValueError:
            continue
        raise AssertionError(f"accepted bad solution {bad!r}")


if __name__ == "__main__":
    for name, fn in list(globals().items()):
        if name.startswith("test_"):
            fn()
    print("all normalize_riddle tests passed")
