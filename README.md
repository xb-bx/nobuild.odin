# nobuild.odin
single-file build system for odin inspired by Tsoding's [nobuild.c](https://github.com/tsoding/nobuild)

## How to use
1. Copy nobuild.odin to your project folder
2. Create mybuild.odin
```odin
  package nobuild
  main :: proc() {
    run("odin", "build", "src", "-out:myprogram.exe")
  }
```
3. Compile build script
`odin build . -out:build.exe`
4. Run build script

### More featureful example you can see there [pvm](https://github.com/xb-bx/pvm)
