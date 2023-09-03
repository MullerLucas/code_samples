#pragma once

#include <cstddef>
#include <cassert>
#include <cstddef>
#include <cstdio>
#include <iostream>
#include <cstring>

namespace hell {

// ----------------------------------------------

template<typename T, std::size_t CAPACITY>
class StackArray
{
private:
    T data[CAPACITY];
    std::size_t len;

public:
    StackArray();
    StackArray(T data[CAPACITY], std::size_t len);
    StackArray(const StackArray& other);

    std::size_t get_len();
    bool is_empty() const;
    bool is_full() const;

    void push(T value);
    T pop();
    const T& peek() const;

    void print() const;
};

// ----------------------------------------------

template<typename T, std::size_t CAPACITY>
StackArray<T, CAPACITY>::StackArray()
    : len(0)
{ }

template<typename T, std::size_t CAPACITY>
StackArray<T, CAPACITY>::StackArray(T data[CAPACITY], std::size_t len)
    : data(data), len(len)
{ }

template<typename T, std::size_t CAPACITY>
StackArray<T, CAPACITY>::StackArray(const StackArray& other)
{
    std::memcpy(this->data, other.data, sizeof(T) * other.len);
    this->len = other.len;
}

template<typename T, std::size_t CAPACITY>
std::size_t StackArray<T, CAPACITY>::get_len()
{
    return this->len;
}

template<typename T, std::size_t CAPACITY>
bool StackArray<T, CAPACITY>::is_empty() const
{
    return this->len == 0;
}

template<typename T, std::size_t CAPACITY>
bool StackArray<T, CAPACITY>::is_full() const
{
    return this->len == CAPACITY;
}

template<typename T, std::size_t CAPACITY>
void StackArray<T, CAPACITY>::push(T value)
{
    assert(!this->is_full());

    this->data[this->len] = value;
    this->len += 1;
}

template<typename T, std::size_t CAPACITY>
T StackArray<T, CAPACITY>::pop()
{
    assert(!this->is_empty());

    this->len -= 1;
    return this->data[this->len];
}

template<typename T, std::size_t CAPACITY>
const T& StackArray<T, CAPACITY>::peek() const
{
    assert(!this->is_empty());

    return this->data[this->len - 1];
}

template<typename T, std::size_t CAPACITY>
void StackArray<T, CAPACITY>::print() const
{
    std::cout << "----------" << std::endl;
    std::cout << "Length: "   << this->len        << std::endl;
    std::cout << "Is empty: " << this->is_empty() << std::endl;
    std::cout << "Is full: "  << this->is_full()  << std::endl;

    for (std::size_t i = 0; i < len; i++)
    {
        std::cout << "Value: " << this->data[i] << std::endl;
    }

    std::cout << "----------" << std::endl;
}

// ----------------------------------------------

}
