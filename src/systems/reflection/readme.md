# Advanced Reflection Mechanism for EnTT

This framework introduces an advanced **meta-reflection** system utilizing EnTT, enabling **dynamic component introspection**, **real-time modification**, and **function invocation** within a component-based architecture.

## 📌 Key Capabilities
- **Automated registration of component metadata**
- **Dynamic component retrieval via reflection**
- **Runtime field modification for enhanced adaptability**
- **Invocation of meta-registered functions dynamically**
- **Conversion of `entt::meta_any` objects into structured string representations**

## 🚀 Implementation Guide

### 1️⃣ **Component Registration**
```cpp
struct MyComponent {
    int health;
};

reflection::registerMetaForComponent<MyComponent>([](auto meta) {
    meta.template data<&MyComponent::health>("health"_hs);
});
```

### 2️⃣ **Retrieving a Component via Reflection**
```cpp
entt::entity entity = registry.create();
registry.emplace<MyComponent>(entity, 100);

auto componentAny = reflection::retrieveComponent(&registry, entity, "MyComponent");
```

### 3️⃣ **Dynamically Modifying Component Fields**
```cpp
reflection::modifyComponentField(componentAny, "MyComponent", "health", entt::meta_any(200));
```

### 4️⃣ **Executing Meta-Registered Functions**
```cpp
entt::meta_any result = reflection::invoke_meta_func(entt::resolve<MyComponent>(), "someFunction"_hs, 42);
```

---

## 📚 System Extensibility
To augment `meta_any_to_string` with specialized type handling, implement a **custom lambda function**:
```cpp
std::string customStr = reflection::meta_any_to_string(myMetaAny, 
    [](const entt::meta_any& any) -> std::optional<std::string> {
        if (any.type() == entt::resolve<MyCustomType>()) {
            return "CustomType Data Representation";
        }
        return {};
    });
```

---

