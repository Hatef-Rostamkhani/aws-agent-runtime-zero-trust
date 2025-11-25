import json
import logging
import os
import boto3
import string
import secrets
from typing import Dict, Any

logger = logging.getLogger()
logger.setLevel(logging.INFO)

secrets_client = boto3.client('secretsmanager')

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Rotate secrets for all services."""

    secrets_to_rotate = json.loads(os.environ.get('SECRETS_TO_ROTATE', '[]'))

    results = {}

    for secret_arn in secrets_to_rotate:
        try:
            secret_name = secret_arn.split(':')[-1]
            logger.info(f"Rotating secret: {secret_name}")

            # Get current secret
            current_secret = secrets_client.get_secret_value(SecretId=secret_arn)
            current_data = json.loads(current_secret['SecretString'])

            # Generate new secrets
            new_data = generate_new_secrets(current_data)

            # Update secret with new values
            secrets_client.update_secret(
                SecretId=secret_arn,
                SecretString=json.dumps(new_data)
            )

            results[secret_name] = "SUCCESS"
            logger.info(f"Successfully rotated secret: {secret_name}")

        except Exception as e:
            error_msg = f"Failed to rotate {secret_name}: {str(e)}"
            results[secret_name] = f"ERROR: {error_msg}"
            logger.error(error_msg)

    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Secrets rotation completed',
            'results': results
        })
    }

def generate_new_secrets(current_data: Dict[str, Any]) -> Dict[str, Any]:
    """Generate new secret values."""

    new_data = {}

    for key, value in current_data.items():
        if key.endswith('_key') or key.endswith('_secret') or key.endswith('_token'):
            # Generate new random string for sensitive values
            new_data[key] = generate_random_string(32)
        elif key.endswith('_password'):
            # Generate new password
            new_data[key] = generate_password()
        else:
            # Keep non-sensitive values (like database URLs)
            new_data[key] = value

    return new_data

def generate_random_string(length: int = 32) -> str:
    """Generate a random string."""
    alphabet = string.ascii_letters + string.digits
    return ''.join(secrets.choice(alphabet) for _ in range(length))

def generate_password(length: int = 16) -> str:
    """Generate a secure password."""
    # Ensure at least one character from each category
    password = [
        secrets.choice(string.ascii_uppercase),
        secrets.choice(string.ascii_lowercase),
        secrets.choice(string.digits),
        secrets.choice(string.punctuation)
    ]

    # Fill the rest randomly
    remaining_length = length - len(password)
    all_chars = string.ascii_letters + string.digits + string.punctuation
    password.extend(secrets.choice(all_chars) for _ in range(remaining_length))

    # Shuffle the password
    secrets.SystemRandom().shuffle(password)

    return ''.join(password)
