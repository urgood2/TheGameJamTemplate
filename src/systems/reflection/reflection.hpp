#pragma once

#include "util/common_headers.hpp"

#include "entt/core/hashed_string.hpp"
#include "entt/meta/factory.hpp"
#include "entt/meta/meta.hpp"
#include "entt/meta/container.hpp"

using namespace entt::literals;

namespace reflection
{

    /**
     * @brief Retrieves a component from an entity or creates it if it doesn't exist.
     *
     * This function fetches a component from an entity within an `entt::registry` dynamically.
     * If the entity does not already have the component, a default-initialized component is emplaced.
     *
     * @tparam TComponent The component type to retrieve.
     * @param registry Pointer to the `entt::registry` managing the entity.
     * @param entity The entity whose component is being retrieved.
     * @return TComponent& A reference to the retrieved or newly emplaced component.
     */
    template <typename TComponent>
    inline auto getComponentFromEntity(entt::registry *registry, entt::entity entity) -> TComponent &
    {
        // SPDLOG_DEBUG("Getting component from entity");
        return registry->get_or_emplace<TComponent>(entity);
    }

    /**
     * @brief Registers a component type in EnTT's meta reflection system.
     *
     * This function registers a component type for dynamic introspection and modification.
     * It also allows extending the metadata using a lambda function.
     *
     * @tparam TComponent The component type to register.
     * @param extendMeta A lambda function to extend metadata (optional).
     */
    template <typename TComponent>
    static void registerMetaForComponent(auto extendMeta = nullptr)
    {
        auto meta = entt::meta<TComponent>()
                        .type(entt::type_hash<TComponent>::value())
                        .template func<&getComponentFromEntity<TComponent>>("getComponentFromEntity"_hs);

        if constexpr (!std::is_null_pointer_v<decltype(extendMeta)>)
        {
            extendMeta(meta);
        }
    }

    /**
     * @brief Generates a runtime hash of a string.
     *
     * Used to generate `entt::id_type` values for dynamically referencing meta types and fields.
     *
     * @param str The string to hash.
     * @return entt::id_type The hashed value.
     */
    inline entt::id_type runtime_hash(const std::string &str)
    {
        return entt::hashed_string{str.c_str()}.value(); // Hashes the string at runtime
    }

    /**
     * @brief Retrieves a component dynamically using EnTT's meta reflection system.
     *
     * This function allows retrieving a component from an entity without knowing its type at compile time.
     * Note that the component name must match the registered name in the meta system exactly.
     *
     * @param registry Pointer to the `entt::registry`.
     * @param entity The entity whose component is being retrieved.
     * @param componentName The name of the component to retrieve.
     * @return entt::meta_any The retrieved component wrapped in `entt::meta_any`.
     */
    inline entt::meta_any retrieveComponent(entt::registry *registry, entt::entity entity, const std::string &componentName)
    {

        // Look up the meta type using the hashed component name
        auto type = entt::resolve(runtime_hash(componentName));
        if (!type)
        {
            SPDLOG_ERROR("Component {} not found", componentName);
            return entt::any{};
        }

        // Retrieve the function that gets the component from the entity
        auto getComponentFunc = type.func("getComponentFromEntity"_hs);
        if (!getComponentFunc)
        {
            SPDLOG_ERROR("Function 'getComponentFromEntity' not found for '{}'", componentName);
            return {};
        }

        // Invoke the function dynamically, passing the registry and entity
        auto anyComponent = getComponentFunc.invoke({}, registry, entity);
        if (!anyComponent)
        {
            SPDLOG_WARN("Entity does not have component: {}", componentName);
            return {};
        }

        // SPDLOG_INFO("Successfully retrieved component: {}", componentName);
        return anyComponent; // Return the retrieved component as an `entt::any`
    }

    /**
     * @brief Retrieves a field value from a component dynamically using EnTT's meta reflection.
     *
     * This function enables accessing a field's value dynamically from a component
     * without needing to know the type at compile time.
     *
     * @param componentAny The `entt::meta_any` component instance.
     * @param componentName The name of the component (as registered in meta reflection).
     * @param fieldName The name of the field to retrieve.
     * @return entt::meta_any The field value wrapped in `entt::meta_any`, or an empty `meta_any` if the field is not found.
     *
     * @example Usage:
     * ```cpp
     * entt::meta_any componentAny = retrieveComponent(&registry, entity, "MyComponent");
     * entt::meta_any fieldValue = retrieveFieldByString(componentAny, "MyComponent", "health");
     * if (fieldValue) {
     *     int health = fieldValue.cast<int>();  // Convert to known type
     * }
     * ```
     */
    inline entt::meta_any retrieveFieldByString(entt::meta_any& componentAny, 
                                                const std::string& componentName, 
                                                const std::string& fieldName) 
    {
        // Resolve the component type dynamically
        auto type = entt::resolve(runtime_hash(componentName));
        if (!type) {
            SPDLOG_ERROR("Component type '{}' not found in meta system.", componentName);
            return {};
        }

        // Retrieve the field metadata
        auto field = type.data(runtime_hash(fieldName));
        if (!field) {
            SPDLOG_ERROR("Field '{}' not found in component '{}'", fieldName, componentName);
            return {};
        }

        // Fetch the field value
        auto fieldValue = field.get(componentAny);
        if (!fieldValue) {
            SPDLOG_WARN("Could not retrieve value for field '{}'", fieldName);
            return {};
        }

        // SPDLOG_INFO("Successfully retrieved '{}.{}'", componentName, fieldName);
        return fieldValue;
    }


    /**
     * @brief Dynamically modifies a field in a component using EnTT reflection.
     *
     * @param componentAny The component wrapped in `entt::meta_any`.
     * @param componentName The name of the component.
     * @param fieldName The name of the field to modify.
     * @param newValue The new value to assign to the field.
     */
    inline void modifyComponentField(entt::meta_any &componentAny, const std::string &componentName, const std::string &fieldName, const entt::meta_any &newValue)
    {
        // Resolve the type dynamically
        auto type = entt::resolve(runtime_hash(componentName));

        if (!type)
        {
            SPDLOG_ERROR("Component type '{}' not found in meta system.", componentName);
            return;
        }

        // Find the field in metadata
        auto field = type.data(runtime_hash(fieldName));

        if (!field)
        {
            SPDLOG_ERROR("Field '{}' not found in component '{}'", fieldName, componentName);
            return;
        }

        // Get current field value
        auto currentValue = field.get(componentAny);
        if (!currentValue)
        {
            SPDLOG_WARN("Could not retrieve value for field '{}'", fieldName);
            return;
        }

        // Check type compatibility before setting
        if (currentValue.type() != newValue.type())
        {
            SPDLOG_ERROR("Type mismatch: Cannot assign '{}' to field '{}'", newValue.type().info().name(), fieldName);
            return;
        }

        // Set the new value
        bool success = field.set(componentAny, newValue);
        if (success)
        {
            SPDLOG_INFO("Successfully updated '{}.{}'", componentName, fieldName);
        }
        else
        {
            SPDLOG_WARN("Failed to update '{}.{}'", componentName, fieldName);
        }
    }

    /**
     * @brief Invokes a meta function dynamically using EnTT's reflection system.
     *
     * This function allows calling a registered meta function using its type and function ID.
     * It abstracts away the process of resolving and invoking functions on meta types dynamically.
     *
     * @tparam Args Variadic template parameters representing the arguments required by the function.
     * @param meta_type The EnTT meta type of the object containing the function.
     * @param function_id The hashed ID of the function to invoke.
     * @param args The arguments to pass to the function.
     * @return entt::meta_any Returns the result of the function call, or an empty `entt::meta_any` if the function does not exist or invocation fails.
     *
     * @note If `meta_type` is invalid (not registered), a warning message should be logged (TODO).
     * @note If `function_id` does not correspond to a registered function, the function returns an empty `entt::meta_any`.
     *
     * @example Usage:
     * ```cpp
     * auto metaType = entt::resolve<MyComponent>();
     * entt::id_type funcID = entt::hashed_string{"someFunction"_hs}.value();
     * entt::meta_any result = invoke_meta_func(metaType, funcID, 42, "Hello");
     * ```
     */
    template <typename... Args>
    inline auto invoke_meta_func(entt::meta_type meta_type,
                                 entt::id_type function_id, Args &&...args)
    {
        if (!meta_type)
        {
            // TODO: Warning message
        }
        else
        {
            if (auto &&meta_function = meta_type.func(function_id); meta_function)
                return meta_function.invoke({}, std::forward<Args>(args)...);
        }
        return entt::meta_any{};
    }

    /**
     * @brief Converts an `entt::meta_any` value to a string representation.
     *
     * This function handles:
     * - Optional types (`std::optional<T>`)
     * - Enums (via `magic_enum`)
     * - `entt::entity` (converted to an integer)
     * - Maps (via EnTT's associative container handling)
     * - Vectors/Lists (via EnTT's container handling)
     * - Booleans
     * - Extendability via a user-defined lambda for additional types.
     *
     * @param any The `entt::meta_any` value to stringify.
     * @param customHandler A lambda to handle custom types. It should return `std::optional<std::string>`.
     * @return std::string The string representation of the value.
     */
    inline std::string meta_any_to_string(const entt::meta_any &any,
                                          std::function<std::optional<std::string>(const entt::meta_any &)> customHandler = {})
    {

        if (!any)
        {
            return "null";
        }

        auto type = any.type();
        std::ostringstream oss;

        // Handle custom type extensions first
        if (customHandler)
        {
            auto customResult = customHandler(any);
            if (customResult)
            {
                return *customResult; // Use the custom string if provided
            }
        }

        // Print type name
        oss << "[" << type.info().name() << "] ";

        // Handle bools
        if (type == entt::resolve<bool>())
        {
            return oss.str() + (any.cast<bool>() ? "true" : "false");
        }

        // Handle primitive types
        if (type == entt::resolve<int>())
            return oss.str() + std::to_string(any.cast<int>());
        if (type == entt::resolve<float>())
            return oss.str() + std::to_string(any.cast<float>());
        if (type == entt::resolve<double>())
            return oss.str() + std::to_string(any.cast<double>());
        if (type == entt::resolve<std::string>())
            return oss.str() + any.cast<std::string>();

        // Handle entt::entity (convert to int)
        if (type == entt::resolve<entt::entity>())
        {
            return oss.str() + std::to_string(static_cast<int>(any.cast<entt::entity>()));
        }

        // Handle Raylib's Vector2
        if (type == entt::resolve<Vector2>())
        {
            Vector2 vec = any.cast<Vector2>();
            return oss.str() + "(" + std::to_string(vec.x) + ", " + std::to_string(vec.y) + ")";
        }

        // Handle std::optional<T>
        if (type == entt::resolve<std::optional<int>>())
        {
            auto optValue = any.cast<std::optional<int>>();
            return oss.str() + (optValue ? std::to_string(*optValue) : "nullopt");
        }
        if (type == entt::resolve<std::optional<float>>())
        {
            auto optValue = any.cast<std::optional<float>>();
            return oss.str() + (optValue ? std::to_string(*optValue) : "nullopt");
        }
        if (type == entt::resolve<std::optional<std::string>>())
        {
            auto optValue = any.cast<std::optional<std::string>>();
            return (optValue ? *optValue : "nullopt");
        }
        if (type == entt::resolve<std::optional<entt::entity>>())
        {
            auto optValue = any.cast<std::optional<entt::entity>>();
            return oss.str() + (optValue ? std::to_string(static_cast<int>(*optValue)) : "nullopt");
        }
        if (type == entt::resolve<std::optional<Vector2>>())
        {
            auto optValue = any.cast<std::optional<Vector2>>();
            return oss.str() + (optValue ? "(" + std::to_string(optValue->x) + ", " + std::to_string(optValue->y) + ")" : "nullopt");
        }

        // Handle enums (using magic_enum)
        if (type.is_enum())
        {
            return oss.str() + (fmt::format("Enum: {}", type.info().name()));
        }

        // Handle maps using EnTT's associative container handling
        if (auto assocMeta = any.as_associative_container())
        {
            oss << "{ ";
            for (auto &&[key, value] : assocMeta)
            {
                oss << meta_any_to_string(key) << " : " << meta_any_to_string(value) << ", ";
            }
            oss << "}";
            return oss.str();
        }

        // Handle sequence containers (vectors, lists) using EnTT
        if (auto seqMeta = any.as_sequence_container())
        {
            oss << "[ ";
            for (auto &&element : seqMeta)
            {
                oss << meta_any_to_string(element) << ", ";
            }
            oss << "]";
            return oss.str();
        }

        // If no special handling, return the type name
        return oss.str() + "<unknown>";
    }

}