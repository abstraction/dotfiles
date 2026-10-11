{
  "document": {
    "block_prefix": "\n",
    "block_suffix": "\n",
    "color": "{{ foreground }}",
    "margin": 2
  },
  "block_quote": {
    "indent": 1,
    "indent_token": "│ ",
    "color": "{{ dark_foreground }}",
    "italic": true
  },
  "paragraph": {},
  "list": {
    "level_indent": 2
  },
  "heading": {
    "block_suffix": "\n",
    "bold": true
  },
  "h1": {
    "prefix": "# ",
    "color": "{{ red }}",
    "bold": true
  },
  "h2": {
    "prefix": "## ",
    "color": "{{ yellow }}",
    "bold": true
  },
  "h3": {
    "prefix": "### ",
    "color": "{{ orange }}",
    "bold": true
  },
  "h4": {
    "prefix": "#### ",
    "color": "{{ cyan }}",
    "bold": true
  },
  "h5": {
    "prefix": "##### ",
    "color": "{{ magenta }}",
    "bold": true
  },
  "h6": {
    "prefix": "###### ",
    "color": "{{ accent }}",
    "bold": false
  },
  "text": {},
  "strikethrough": {
    "crossed_out": true,
    "color": "{{ muted }}"
  },
  "emph": {
    "italic": true,
    "color": "{{ bright_foreground }}"
  },
  "strong": {
    "bold": true,
    "color": "{{ bright_foreground }}"
  },
  "hr": {
    "color": "{{ selection }}",
    "format": "\n────────────────────────────────────────\n"
  },
  "item": {
    "block_prefix": "• ",
    "color": "{{ accent }}"
  },
  "enumeration": {
    "block_prefix": ". ",
    "color": "{{ cyan }}"
  },
  "task": {
    "ticked": "[✓] ",
    "unticked": "[ ] ",
    "color": "{{ green }}"
  },
  "link": {
    "color": "{{ cyan }}",
    "underline": true
  },
  "link_text": {
    "color": "{{ accent }}",
    "bold": true
  },
  "image": {
    "color": "{{ cyan }}",
    "underline": true
  },
  "image_text": {
    "color": "{{ dark_foreground }}",
    "format": "Image: {{.text}} →"
  },
  "code": {
    "prefix": " ",
    "suffix": " ",
    "color": "{{ orange }}",
    "background_color": "{{ lighter_background }}"
  },
  "code_block": {
    "color": "{{ foreground }}",
    "margin": 2,
    "chroma": {
      "text": {
        "color": "{{ foreground }}"
      },
      "error": {
        "color": "{{ bright_foreground }}",
        "background_color": "{{ red }}"
      },
      "comment": {
        "color": "{{ muted }}",
        "italic": true
      },
      "comment_preproc": {
        "color": "{{ orange }}"
      },
      "keyword": {
        "color": "{{ magenta }}",
        "bold": true
      },
      "keyword_reserved": {
        "color": "{{ magenta }}",
        "bold": true
      },
      "keyword_namespace": {
        "color": "{{ magenta }}"
      },
      "keyword_type": {
        "color": "{{ yellow }}"
      },
      "operator": {
        "color": "{{ cyan }}"
      },
      "punctuation": {
        "color": "{{ dark_foreground }}"
      },
      "name": {
        "color": "{{ foreground }}"
      },
      "name_builtin": {
        "color": "{{ orange }}"
      },
      "name_tag": {
        "color": "{{ accent }}"
      },
      "name_attribute": {
        "color": "{{ cyan }}"
      },
      "name_class": {
        "color": "{{ yellow }}",
        "bold": true
      },
      "name_constant": {
        "color": "{{ orange }}"
      },
      "name_decorator": {
        "color": "{{ blue }}"
      },
      "name_function": {
        "color": "{{ blue }}",
        "bold": true
      },
      "literal_number": {
        "color": "{{ orange }}"
      },
      "literal_string": {
        "color": "{{ green }}"
      },
      "literal_string_escape": {
        "color": "{{ cyan }}"
      },
      "generic_deleted": {
        "color": "{{ red }}"
      },
      "generic_emph": {
        "italic": true
      },
      "generic_inserted": {
        "color": "{{ green }}"
      },
      "generic_strong": {
        "bold": true
      },
      "generic_subheading": {
        "color": "{{ cyan }}"
      },
      "background": {
        "background_color": "{{ lighter_background }}"
      }
    }
  },
  "table": {
    "center_separator": "┼",
    "column_separator": "│",
    "row_separator": "─"
  },
  "definition_list": {},
  "definition_term": {
    "bold": true,
    "color": "{{ bright_foreground }}"
  },
  "definition_description": {
    "block_prefix": "\n🠶 ",
    "color": "{{ dark_foreground }}"
  },
  "html_block": {},
  "html_span": {}
}
