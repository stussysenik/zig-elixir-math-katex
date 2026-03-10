import dspy
import json
import os
from pydantic import BaseModel, Field
from typing import List, Optional

# Define our Pydantic schema mirroring the Ecto schemas
class DesmosExpression(BaseModel):
    id: str
    latex: str

class AIResponseSchema(BaseModel):
    mode: str = Field(description="Must be 'computation' or 'chat'")
    reasoning_steps: List[str] = Field(description="1-4 short strings describing the math transformation")
    raw_latex: Optional[str] = Field(default=None, description="KaTeX-ready LaTeX for the intended result")
    sympy_executable: Optional[str] = Field(default=None, description="A single SymPy-safe expression")
    desmos_expressions: Optional[List[DesmosExpression]] = Field(default=[], description="List of expressions for graphable results")
    chat_reply: Optional[str] = Field(default=None, description="Prose reply for chat mode")

# Define the DSPy Signature for Math extraction
class MathExtraction(dspy.Signature):
    """You translate a natural-language math request into a strict JSON object for a verified-first symbolic pipeline.
    Output must be a valid JSON object matching the required schema."""
    
    input = dspy.InputField(desc="The user's mathematical query or request.")
    expected_response: AIResponseSchema = dspy.OutputField(desc="Strictly formatted JSON containing the analytical mode, reasoning steps, and computation or chat fields.")

# Dummy metric checking if the output is valid JSON and has required keys
def math_metric(gold, pred, trace=None):
    try:
        # Pydantic validation guarantees JSON structural fidelity. 
        # For metric scoring, we ensure mode is matched.
        is_correct_mode = getattr(pred.expected_response, 'mode', '') == gold.expected['mode']
        
        # Verify it has reasoning steps
        has_reasoning = len(getattr(pred.expected_response, 'reasoning_steps', [])) > 0
        
        return is_correct_mode and has_reasoning
    except Exception as e:
        return False

def main():
    api_key = os.environ.get("NVIDIA_NIM_API_KEY")
    if not api_key:
        print("Skipping DSPy eval: NVIDIA_NIM_API_KEY not set.")
        return

    # Configure DSPy to use NVIDIA NIM
    nim_lm = dspy.LM("openai/moonshotai/kimi-k2-5", api_base="https://integrate.api.nvidia.com/v1", api_key=api_key)
    dspy.configure(lm=nim_lm)

    # Load dataset
    with open("eval/dataset.json", "r") as f:
        data = json.load(f)
        
    dataset = [dspy.Example(input=item["input"], expected=item["expected"]).with_inputs("input") for item in data]
    
    # Run a simple Predict module without optimization just to test fidelity
    predictor = dspy.Predict(MathExtraction)
    
    print(f"Running evaluation on {len(dataset)} examples...")
    
    correct = 0
    for ex in dataset:
        try:
            pred = predictor(input=ex.input)
            score = math_metric(ex, pred)
            if score:
                correct += 1
            print(f"Input: {ex.input} | Score: {score}")
        except Exception as e:
            print(f"Input: {ex.input} | Error: {e}")
            
    print(f"Accuracy: {correct}/{len(dataset)} ({(correct/len(dataset))*100:.1f}%)")
    
    # In a full run, we would use dspy.teleprompt.BootstrapFewShot to optimize here
    # optimizer = dspy.teleprompt.BootstrapFewShot(metric=math_metric)
    # optimized_predictor = optimizer.compile(predictor, trainset=dataset)
    # optimized_predictor.save("eval/optimized_prompt.json")

if __name__ == "__main__":
    main()
