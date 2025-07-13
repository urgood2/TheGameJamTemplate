#pragma once

#include "util/common_headers.hpp"
#include "third_party/objectpool-master/src/object_pool.hpp"



namespace layer {
    struct IDynamicPool {
        virtual ~IDynamicPool() = default;
        virtual void delete_all() = 0;
        virtual ObjectPoolStats calc_stats() const = 0;
    };

    template<typename T>
    struct DynamicObjectPoolWrapper : IDynamicPool {
        DynamicObjectPool<T> pool;

        DynamicObjectPoolWrapper(detail::index_t entries_per_block)
            : pool(entries_per_block) {}

        template<typename... Args>
        T* create(Args&&... args) {
            return pool.new_object(std::forward<Args>(args)...);
        }

        T* new_object() {
            return pool.new_object();  // or whatever your underlying pool uses
        }

        void delete_object(const T* ptr) {
            pool.delete_object(ptr);
        }

        void delete_all() override {
            pool.delete_all();
        }

        ObjectPoolStats calc_stats() const override {
            return pool.calc_stats();
        }
    };
}