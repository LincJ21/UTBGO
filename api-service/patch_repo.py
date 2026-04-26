import re

file_path = 'repository_postgres.go'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    "COALESCE(p.nombre, 'Usuario') as author_name\n\t\tFROM", 
    "COALESCE(p.nombre, 'Usuario') as author_name, c.id_autor\n\t\tFROM"
)

content = content.replace(
    "COALESCE(p.nombre, 'Usuario') as author_name FROM", 
    "COALESCE(p.nombre, 'Usuario') as author_name, c.id_autor FROM"
)

content = re.sub(
    r'rows\.Scan\((.*?)\&v\.AuthorName\)',
    r'rows.Scan(\1&v.AuthorName, &v.AuthorID)',
    content
)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
