with open('logo_base64.txt', 'r') as f:
    b64 = f.read().strip()

img_tag = f'<img src="data:image/png;base64,{b64}" alt="Partwk Logo" style="height: 50px; margin-bottom: 15px;" />'

with open('index.js', 'r') as f:
    content = f.read()

content = content.replace(
    '<h1 style="color: #F59E0B; margin: 0;">Welcome to Partwk!</h1>',
    f'{img_tag}\n    <h1 style="color: #F59E0B; margin: 0;">Welcome to Partwk!</h1>'
)
content = content.replace(
    '<h1 style="color: #1E293B; margin: 0;">Welcome to Premium! 👑</h1>',
    f'{img_tag}\n    <h1 style="color: #1E293B; margin: 0;">Welcome to Premium! 👑</h1>'
)

with open('index.js', 'w') as f:
    f.write(content)

with open('test_email.js', 'w') as f:
    f.write(content.replace('exports.onUserCreated', '// exports.onUserCreated').replace('exports.onUserUpdated', '// exports.onUserUpdated'))
