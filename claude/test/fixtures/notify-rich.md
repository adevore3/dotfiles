# Markdown conversion test

This checks **bold**, *italic*, ~~strikethrough~~, and a [link](https://example.com) render natively in Slack.

Key points:
- First bullet with **bold** inside
- Second bullet with `inline code` left intact
- A third bullet

Here's a fenced code block (language tag should be dropped, body untouched):

```python
def f(a, b):
    return a**b  # **not** bold in here
```

That's the whole test. <!-- needs-input -->
