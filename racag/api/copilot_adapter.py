# racag/api/copilot_adapter.py

from fastapi import APIRouter
from pydantic import BaseModel
from racag.query import query_racag
from racag.context.context_assembler import context_to_markdown

router = APIRouter()

class CopilotRequest(BaseModel):
    prompt: str
    top_k: int = 5

@router.post("/contextualize")
def contextualize(req: CopilotRequest):
    """
    Takes a plain Copilot prompt, retrieves RACAG context,
    formats it using the unified metadata schema,
    and returns a fully assembled superprompt.
    """
    context_bundle = query_racag(req.prompt, top_k=req.top_k)

    # context_bundle["items"] = list of dicts with unified metadata schema
    context_markdown = context_to_markdown(context_bundle["items"])

    superprompt = f"""# USER PROMPT
{req.prompt}

# CONTEXT FROM PROJECT (RACAG)
{context_markdown}

# INSTRUCTIONS FOR THE LLM
- Use ONLY the provided context and code.
- Do NOT hallucinate missing functions, classes, or modules.
- Prefer exact identifiers, structures, and types extracted from the project.
- If context is insufficient, ask for clarification.
"""

    return {
        "prompt": req.prompt,
        "context_used": context_markdown,
        "superprompt": superprompt,
    }