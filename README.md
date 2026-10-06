# Fragment

**Fragment** is a lightweight 3D/2D rendering framework built with **LÖVE**, designed around a Roblox-inspired object hierarchy for fast, flexible development.

It combines a simple instance-based scene system with custom meshes, shaders, lighting, rendering styles, and utility modules while keeping the underlying API straightforward.

## Features

* **Roblox-inspired object hierarchy**

  * Parent/child relationships
  * Descendant traversal
  * Class-based objects
  * `FindFirstChild` and `FindFirstChildOfClass`
  * `IsA` and full-name resolution
  * Ancestry and child signals
  * Safe object destruction

* **Custom 3D renderer**

  * Hardware-accelerated rendering through LÖVE
  * Perspective projection
  * Camera system
  * Model transforms
  * Normal-matrix support for non-uniform scaling
  * Depth testing
  * Transparency sorting
  * Directional lighting and ambient lighting

* **Multiple render styles**

  * Shaded
  * Outline
  * Wireframe
  * Normals
  * Depth

* **Built-in mesh definitions**

  * Cube
  * Square
  * Circle
  * Pyramid
  * Wedge
  * Icosphere with adjustable detail

* **Shader system**

  * Vertex and pixel shader support
  * Combined GLSL shader files
  * Shader caching
  * Shader reloading
  * Uniform management
  * Automatic matrix conversion

* **2D GUI utilities**

  * Text rendering
  * Text measurement
  * Scaling
  * Color support

* **Math utilities**

  * 4×4 matrices
  * Perspective projection
  * Look-at camera matrices
  * Translation
  * Scaling
  * Euler rotations
  * TRS transformations

## Example

Creating objects follows a simple hierarchy-based API:

```lua
local Camera = Object.New("Camera", Workspace)

Camera.Position = {0, 24, 0}
Camera.Rotation = {-90, 0, 0}
Camera.Fov = 50

Workspace.Camera = Camera

local Part = Object.New("Part", Workspace)

Part.Size = {4, 4, 4}
Part.Position = {0, 0, 0}
Part.Rotation = {0, 0, 0}
Part.RenderStyle = Enum.RenderStyle.Outline
Part.Mesh = Enum.Mesh.Icosphere(1)
Part.Color = {0.25, 1, 1}
```

Objects can then be organized naturally through their hierarchy:

```text
Workspace
├── Camera
├── Part
├── Part
└── Model
    ├── Part
    └── Part
```

The renderer traverses this hierarchy and handles the appropriate rendering passes automatically.

## Project Structure

```text
Fragment/
├── main.lua
├── Assets/
│   └── Shaders/
│       └── Vertex.glsl
└── Services/
    ├── Enum.lua
    ├── Gui.lua
    ├── Matrix.lua
    ├── Object.lua
    ├── Renderer.lua
    └── Shader.lua
```

## Philosophy

Fragment is focused on **development speed without throwing away control**.

The goal is to provide a high-level scene and object system while keeping rendering, shaders, meshes, transformations, and graphics behavior accessible when lower-level control is needed.

Instead of building a large engine around dozens of specialized systems, Fragment keeps its core around a few composable concepts:

**Objects → Hierarchy → Renderer → Shaders**

## Status

Fragment is currently an **experimental / actively developed project**. APIs and internal systems may change as the renderer and object framework evolve.

## Requirements

* [LÖVE](https://love2d.org/)
* A GPU supporting the graphics features used by LÖVE and the included GLSL shaders