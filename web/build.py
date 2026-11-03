import pathlib
root = pathlib.Path(__file__).parent
src = root / 'src'
shell = (src / 'shell.html').read_text()
css = (src / 'style.css').read_text()
js = '\n'.join((src / f).read_text() for f in ['data.js', 'data2.js', 'util.js', 'tune.js', 'engine.js', 'race.js', 'gfx.js', 'tunegfx.js', 'ui.js', 'ui2.js', 'main.js'])
assert '</script' not in js.lower()
out = shell.replace('/*CSS*/', css).replace('/*JS*/', js)
(root / 'dist' / 'index.html').write_text(out)
print('built', len(out), 'bytes')
