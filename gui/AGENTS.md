# Application language rule

Implement GUI application behavior in Rust. Keep the original UI in QML.
Preserve original names, text, layout, assets, interactions and workflows.
Do not replace the original QML with a new UI framework or custom screen.
Do not add handwritten C or C++ source or inline C or C++ payloads.

External Qt and binding libraries remain dependencies. Their build-generated
bindings and resource code must stay outside tracked application source.
Use Rust declarations to bind their APIs. Do not move application behavior into
a C++ wrapper or change file extensions to bypass this rule.
Report external and generated C++ accurately. Do not call the stack C++-free.

Follow the repository instructions for claims, comms, validation and review.
Run the application language check before publication.
