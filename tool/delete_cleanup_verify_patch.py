from pathlib import Path

path = Path('firestore.rules')
text = path.read_text()
old = """    match /{path=**}/joinRequests/{uid} {
      allow list: if linkedCommunityAccount()
        && resource.data.userId == request.auth.uid;
    }
"""
new = """    match /{path=**}/joinRequests/{uid} {
      allow list: if signedIn()
        && resource.data.userId == request.auth.uid;
    }
"""
if old not in text:
    raise SystemExit('Expected joinRequests collection-group rule not found')
path.write_text(text.replace(old, new, 1))
