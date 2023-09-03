# README - Code Samples

- All projects are mirrored from GitLab to GitHub.
- Most files come from projects that are under (active) development.
- To shorten the file, some code has been removed. Other than that, the files are unchanged.



## bachelor_thesis

### Info

- C# class used in my bachelor Unity project
- Based on the Unity-DOTS API

### Files

- `cost_system.cs`
    - The flow field is divided into multiple segments of which each segment contains a grid of smaller cells
    - In this class, a job is created that runs parallely on each segment and determines wheather the cells in that segment are blocked or passable

---

## goeff

- https://gitlab.com/helloki/goeff

- `chat.rs`
    - View, responsible for rendering the chat page

---

## hector

### Info

- https://gitlab.com/helloki/hector
- https://github.com/MullerLucas/hector
- Contains basic data structures and algorithms written in C++

### Files

- `bs_tree.hpp`
    - Binary-Search-Tree
- `linked_list.hpp`
    - Linked-List
- `stack_array.hpp`
    - Stack (array backed)

---

## hellengine

### Info

- https://gitlab.com/helloki/hellengine
- https://github.com/MullerLucas/hellengine
- https://gitlab.com/helloki/nocoru
- https://github.com/MullerLucas/nocoru
- The `hellmut` and `hellengine` are currently being merged into one project.
- Personal project written in Rust.
- Vulkan is used as the graphics API.


### Files

- `shader_crap_grammar.txt`
    - Crate: shader_crap
    - PEG definition file
- `shader_crap_input.glsl`
    - Crate: shader_crap
    - Example shader input
- `shader_crap_out_vert.glsl`
    - Crate: shader_crap
    - Example shader output (vertex shader)
- `vulkan_memory.rs`
    - Crate: hell_renderer
    - Wrapper for working with Vulkan device memory and mapped memory regions
- `vec.rs`
    - Crate: hell_math
    - Vector math library based on macros

---

## hellengine_zig

### Info

- https://gitlab.com/helloki/hellengine_zig
- https://github.com/MullerLucas/hellengine_zig

### Files

- `obj_file.zig`
    - Simple obj file parser
- `slot_array.zig`
    - Simple implementation of a slot array data structure
- `vulkan_backend.zig`
    - The renderer has been split into a generic frontend and an api specific backend - This is the backend for Vulkan
    - Functions for creating and generic shaders

---

## hellmut

### Info

- https://gitlab.com/helloki/hellmut
- https://github.com/MullerLucas/hellmut
- The `hellmut` and `hellengine` are currently being merged into one project
- Contains a simple Rust + WASM based client framework, similar to Leptos
- Contains libraries for working with large language models like openAI's Chat-GPT

### Files

- `context.rs`
    - Reactive system, responsible for creating and running effects and signals
- `element.rs`
    - Wrapper for working with html elements
