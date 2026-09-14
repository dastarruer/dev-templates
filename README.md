# dev-templates

My personal collection of flake templates. Good for quickly jumping into a project.

To initialize a template:

```sh
nix flake init -t github:dastarruer/dev-templates#${TEMPLATE}
```

For example, if you want to initialize the rust template:

```sh
nix flake init -t github:dastarruer/dev-templates#rust
```

The following environments are available:

- `#rust`