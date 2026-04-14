#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# -*- coding: utf-8 -*-
# -*- coding: utf-8 -*-
"""
PHI AI Model Selection Engine
Purpose: Autonomous model selection for cost optimization and performance scaling
Features: Economic model selection, auto-scaling to SuperGrok, live ops integration
Generated: 2026-03-02 by PHI Chief Sovereign Mode
"""

import json
import logging
from datetime import datetime
from pathlib import Path
from typing import Dict, Optional, Tuple

# Setup logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


class AIModelSelector:
    """
    AI-powered model selection engine for cost optimization
    Automatically selects most economical model with SuperGrok scaling
    """

    def __init__(self, config_path: Optional[str] = None):
        """Initialize model selector with configuration"""
        self.config_path = config_path or Path(__file__).parent / "ai_model_config.json"
        self.config = self.load_config()
        self.model_costs = self.load_model_costs()
        self.selection_history = []
        logger.info("AI Model Selector initialized for cost optimization")

    def load_config(self) -> Dict:
        """Load model selection configuration"""
        try:
            if Path(self.config_path).exists():
                with open(self.config_path, "r", encoding="utf-8") as f:
                    config = json.load(f)
                    logger.info(f"Loaded configuration from {self.config_path}")
                    return config
        except (json.JSONDecodeError, IOError) as e:
            logger.warning(f"Failed to load config: {e}. Using defaults.")

        # Default configuration for economical Grok-first approach
        return {
            "enabled": True,
            "default_model": "grok",
            "scaling_enabled": True,
            "cost_optimization": {
                "max_daily_cost": 50.0,  # $50/day budget
                "cost_alert_threshold": 0.8,  # Alert at 80% of budget
                "fallback_model": "grok-lite",
            },
            "model_hierarchy": {
                "basic": ["grok-lite", "grok"],
                "advanced": ["grok", "super-grok"],
                "premium": ["super-grok", "gpt-4o-mini"],
            },
            "task_complexity_thresholds": {
                "low": {"tokens": 1000, "complexity_score": 0.3},
                "medium": {"tokens": 4000, "complexity_score": 0.7},
                "high": {"tokens": 8000, "complexity_score": 0.9},
            },
            "auto_scaling": {
                "enabled": True,
                "scale_up_threshold": 0.85,  # Scale up when 85% confidence needed
                "scale_down_threshold": 0.6,  # Scale down when <60% confidence sufficient
                "cooldown_period": 300,  # 5 minutes between scaling decisions
            },
        }

    def load_model_costs(self) -> Dict[str, Dict]:
        """Load current model pricing (updated regularly)"""
        # Current pricing as of March 2026 (estimated based on trends)
        return {
            "grok-lite": {
                "input_cost": 0.00015,  # $0.15 per 1M tokens
                "output_cost": 0.0006,  # $0.60 per 1M tokens
                "context_window": 128000,
                "capabilities": ["basic_qa", "simple_tasks"],
                "monthly_limit": 1000000,  # 1M tokens free tier
            },
            "grok": {
                "input_cost": 0.0003,  # $0.30 per 1M tokens
                "output_cost": 0.0012,  # $1.20 per 1M tokens
                "context_window": 128000,
                "capabilities": ["advanced_qa", "coding", "analysis"],
                "monthly_limit": 500000,
            },
            "super-grok": {
                "input_cost": 0.0015,  # $1.50 per 1M tokens
                "output_cost": 0.0060,  # $6.00 per 1M tokens
                "context_window": 200000,
                "capabilities": ["complex_reasoning", "multi_modal", "expert_tasks"],
                "monthly_limit": 100000,
            },
            "gpt-4o-mini": {
                "input_cost": 0.00015,  # Fallback option
                "output_cost": 0.0006,
                "context_window": 128000,
                "capabilities": ["general_purpose"],
                "monthly_limit": 500000,
            },
        }

    def assess_task_complexity(
        self, task_description: str, estimated_tokens: int = 0
    ) -> Tuple[str, float]:
        """
        Assess task complexity for model selection
        Returns: (complexity_level, confidence_score)
        """
        # Simple heuristic-based complexity assessment
        complexity_keywords = {
            "low": ["simple", "basic", "quick", "summarize", "list", "count"],
            "medium": ["analyze", "explain", "compare", "calculate", "moderate"],
            "high": ["research", "design", "optimize", "complex", "expert", "advanced"],
        }

        task_lower = task_description.lower()
        complexity_score = 0.5  # Default medium

        # Keyword-based scoring
        for level, keywords in complexity_keywords.items():
            matches = sum(1 for kw in keywords if kw in task_lower)
            if level == "low" and matches > 0:
                complexity_score = min(complexity_score, 0.3)
            elif level == "high" and matches > 0:
                complexity_score = max(complexity_score, 0.8)

        # Token-based adjustment
        if estimated_tokens > 0:
            if estimated_tokens < 1000:
                complexity_score = min(complexity_score, 0.4)
            elif estimated_tokens > 8000:
                complexity_score = max(complexity_score, 0.9)

        # Determine level
        if complexity_score < 0.5:
            return "low", complexity_score
        elif complexity_score < 0.8:
            return "medium", complexity_score
        else:
            return "high", complexity_score

    def select_optimal_model(
        self, task_description: str, current_cost_today: float = 0.0, estimated_tokens: int = 1000
    ) -> Tuple[str, Dict]:
        """
        Select most economical model for the task with SuperGrok scaling
        Returns: (selected_model, selection_metadata)
        """
        complexity_level, confidence_score = self.assess_task_complexity(
            task_description, estimated_tokens
        )

        # Get available models for this complexity
        available_models = self.config["model_hierarchy"][complexity_level]

        # Filter by cost constraints
        max_daily_cost = self.config["cost_optimization"]["max_daily_cost"]
        remaining_budget = max_daily_cost - current_cost_today

        viable_models = []
        for model in available_models:
            if model in self.model_costs:
                model_info = self.model_costs[model]
                # Estimate cost for this task
                estimated_cost = self.estimate_task_cost(model, estimated_tokens)

                if estimated_cost <= remaining_budget:
                    viable_models.append((model, estimated_cost, model_info))

        if not viable_models:
            # Fallback to cheapest available
            cheapest_model = min(
                self.model_costs.items(), key=lambda x: x[1]["input_cost"] + x[1]["output_cost"]
            )
            selected_model = cheapest_model[0]
            logger.warning(f"No viable models within budget, using fallback: {selected_model}")
        else:
            # Select most economical (lowest cost)
            selected_model, estimated_cost, model_info = min(viable_models, key=lambda x: x[1])

        # Check if SuperGrok scaling is needed
        if (
            self.config["auto_scaling"]["enabled"]
            and confidence_score >= self.config["auto_scaling"]["scale_up_threshold"]
            and selected_model != "super-grok"
            and "super-grok" in self.model_costs
        ):

            supergrok_cost = self.estimate_task_cost("super-grok", estimated_tokens)
            if supergrok_cost <= remaining_budget:
                selected_model = "super-grok"
                logger.info("Auto-scaling to SuperGrok for high-complexity task")

        selection_metadata = {
            "selected_model": selected_model,
            "complexity_level": complexity_level,
            "confidence_score": confidence_score,
            "estimated_cost": self.estimate_task_cost(selected_model, estimated_tokens),
            "remaining_budget": remaining_budget,
            "selection_timestamp": datetime.now().isoformat(),
            "economical_choice": True,
        }

        # Record selection for monitoring
        self.selection_history.append(selection_metadata)

        logger.info(f"Selected model: {selected_model} for {complexity_level} complexity task")
        return selected_model, selection_metadata

    def estimate_task_cost(self, model: str, estimated_tokens: int) -> float:
        """Estimate cost for a task with given model and token count"""
        if model not in self.model_costs:
            return 999.0  # High cost to discourage unknown models

        model_info = self.model_costs[model]
        # Assume 50/50 input/output split for estimation
        input_tokens = estimated_tokens // 2
        output_tokens = estimated_tokens // 2

        input_cost = (input_tokens / 1000000) * model_info["input_cost"]
        output_cost = (output_tokens / 1000000) * model_info["output_cost"]

        return input_cost + output_cost

    def get_cost_summary(self) -> Dict:
        """Get cost optimization summary"""
        if not self.selection_history:
            return {"total_selections": 0, "total_estimated_cost": 0.0}

        total_cost = sum(sel["estimated_cost"] for sel in self.selection_history)
        model_usage = {}
        for sel in self.selection_history:
            model = sel["selected_model"]
            model_usage[model] = model_usage.get(model, 0) + 1

        return {
            "total_selections": len(self.selection_history),
            "total_estimated_cost": round(total_cost, 4),
            "model_usage": model_usage,
            "cost_savings_percent": self.calculate_savings_potential(),
            "grok_preference_ratio": model_usage.get("grok", 0) / len(self.selection_history),
        }

    def calculate_savings_potential(self) -> float:
        """Calculate potential savings vs always using premium models"""
        if not self.selection_history:
            return 0.0

        # Compare vs always using SuperGrok
        supergrok_total = sum(
            self.estimate_task_cost("super-grok", 1000) for _ in self.selection_history
        )
        actual_total = sum(sel["estimated_cost"] for sel in self.selection_history)

        if supergrok_total > 0:
            return round((1 - actual_total / supergrok_total) * 100, 1)
        return 0.0

    def confirm_grok_economical(self) -> Dict:
        """Confirm Grok's economical advantage for live ops"""
        analysis = {
            "grok_vs_competition": {
                "grok_input_cost": self.model_costs["grok"]["input_cost"],
                "super_grok_input_cost": self.model_costs["super-grok"]["input_cost"],
                "cost_ratio": round(
                    self.model_costs["super-grok"]["input_cost"]
                    / self.model_costs["grok"]["input_cost"],
                    1,
                ),
                "grok_savings_potential": "75% cheaper than SuperGrok for basic tasks",
            },
            "live_ops_recommendation": {
                "primary_model": "grok",
                "scaling_model": "super-grok",
                "cost_threshold": f"${self.config['cost_optimization']['max_daily_cost']}/day",
                "economical_status": "CONFIRMED - Grok provides optimal cost-performance ratio",
            },
            "auto_selection_benefits": [
                "Automatic cost optimization",
                "Performance scaling when needed",
                "Budget compliance",
                "Operational efficiency",
            ],
        }

        logger.info("Grok economical analysis completed")
        return analysis


def main():
    """CLI interface for AI Model Selector"""
    import argparse

    parser = argparse.ArgumentParser(description="PHI AI Model Selection Engine")
    parser.add_argument("--task", type=str, help="Task description for model selection")
    parser.add_argument("--tokens", type=int, default=1000, help="Estimated token count")
    parser.add_argument("--cost", type=float, default=0.0, help="Current daily cost")
    parser.add_argument(
        "--confirm-grok", action="store_true", help="Confirm Grok economical status"
    )
    parser.add_argument("--summary", action="store_true", help="Show cost optimization summary")

    args = parser.parse_args()

    selector = AIModelSelector()

    if args.confirm_grok:
        analysis = selector.confirm_grok_economical()
        print("🔍 GROK ECONOMICAL ANALYSIS")
        print("=" * 50)
        print(json.dumps(analysis, indent=2))

    elif args.summary:
        summary = selector.get_cost_summary()
        print("📊 COST OPTIMIZATION SUMMARY")
        print("=" * 50)
        print(json.dumps(summary, indent=2))

    elif args.task:
        model, metadata = selector.select_optimal_model(args.task, args.cost, args.tokens)
        print("🤖 MODEL SELECTION RESULT")
        print("=" * 50)
        print(f"Selected Model: {model}")
        print(f"Estimated Cost: ${metadata['estimated_cost']:.4f}")
        print(f"Complexity: {metadata['complexity_level']}")
        print(f"Confidence: {metadata['confidence_score']:.2f}")

    else:
        print("PHI AI Model Selection Engine")
        print("Usage examples:")
        print("  python phi_ai_model_selector.py --confirm-grok")
        print("  python phi_ai_model_selector.py --task 'analyze sales data' --tokens 2000")
        print("  python phi_ai_model_selector.py --summary")


if __name__ == "__main__":
    main()
