#!/usr/bin/env python3
"""
Script to load default policies into DynamoDB.
"""

import json
import os
import sys
from decimal import Decimal

import boto3


def load_policies(table_name: str, policies_file: str):
    """Load policies from JSON file into DynamoDB."""

    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(table_name)

    with open(policies_file, 'r') as f:
        policies = json.load(f)

    for policy in policies:
        # Convert numeric values to Decimal for DynamoDB
        def convert_numbers(obj):
            if isinstance(obj, dict):
                return {k: convert_numbers(v) for k, v in obj.items()}
            elif isinstance(obj, list):
                return [convert_numbers(item) for item in obj]
            elif isinstance(obj, (int, float)):
                return Decimal(str(obj))
            else:
                return obj

        policy_item = convert_numbers(policy)

        try:
            table.put_item(Item=policy_item)
            print(f"✓ Loaded policy: {policy['service']}:{policy['intent']}")
        except Exception as e:
            print(f"✗ Failed to load policy {policy['service']}:{policy['intent']}: {str(e)}")


if __name__ == "__main__":
    table_name = os.environ.get('POLICY_TABLE_NAME')
    
    # Get policies file path - check if provided as argument or use default
    if len(sys.argv) > 1:
        policies_file = sys.argv[1]
    else:
        # Default to policies/default.json relative to script location
        script_dir = os.path.dirname(os.path.abspath(__file__))
        policies_file = os.path.join(script_dir, '..', 'policies', 'default.json')

    if not table_name:
        print("Error: POLICY_TABLE_NAME environment variable not set")
        sys.exit(1)

    if not os.path.exists(policies_file):
        print(f"Error: Policies file not found: {policies_file}")
        sys.exit(1)

    load_policies(table_name, policies_file)
    print("Policy loading completed")

