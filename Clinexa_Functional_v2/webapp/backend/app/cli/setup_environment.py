from pathlib import Path
import secrets

if __name__ == '__main__':
    if Path('.env').exists() or Path('../.env').exists():
        print('Existing environment preserved.')
    else:
        Path('.env').write_text('ENVIRONMENT=development\nDATABASE_URL=sqlite:///./clinexa_dev.db\nSECRET_KEY=' + secrets.token_urlsafe(48) + '\nOLLAMA_MODEL=qwen3:1.7b\n', encoding='utf-8')
        print('Created local configuration with a unique signing key.')
