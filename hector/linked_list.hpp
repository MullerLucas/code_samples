#pragma once

#include <algorithm>
#include <cassert>
#include <cstddef>
#include <cstdio>
#include <iostream>
#include <ostream>
#include <utility>

namespace hell {

// ----------------------------------------------

template<typename T>
struct LinkedListNode
{
    T value;
    std::size_t len;
    LinkedListNode<T>* next;
    LinkedListNode<T>* prev;
};

// ----------------------------------------------

template<typename T>
class LinkedList
{
private:
    LinkedListNode<T>* head;
    LinkedListNode<T>* tail;
    std::size_t len;

public:
    LinkedList();
    LinkedList(const LinkedList& other);
    LinkedList(LinkedList&& other);
    ~LinkedList();

    LinkedList<T>& operator=(const LinkedList<T>& other);
    LinkedList<T>& operator=(LinkedList<T>&& other);

    std::size_t get_len() const;

    void push_head(const T& value);
    void push_head(T&& value);
    void push_tail(const T& value);
    void push_tail(T&& value);
    void insert_at(std::size_t idx, const T& value);
    void insert_at(std::size_t idx, T&& value);

    T pop_head();
    T pop_tail();
    T remove_at(std::size_t idx);

    const T& peek_head() const;
    const T& peek_tail() const;
    const T& peek_at(std::size_t idx) const;

    void print() const;

private:
    LinkedListNode<T>* find_at(std::size_t idx) const;
    void delete_all_nodes();

};

// ----------------------------------------------

template<typename T>
LinkedList<T>::LinkedList()
    : head(nullptr), tail(nullptr), len(0)
{ }

template<typename T>
LinkedList<T>::LinkedList(const LinkedList<T>& other)
    : head(nullptr), tail(nullptr), len(other.len)
{
    auto other_node = other.head;
    while (other_node != nullptr)
    {
        this->push_tail(std::move(other_node->value));
        other_node = other_node->next;
    }
}

template<typename T>
LinkedList<T>::LinkedList(LinkedList<T>&& other)
    : head(std::exchange(other.head, nullptr))
    , tail(std::exchange(other.tail, nullptr))
    , len (std::exchange(other.len,  0))
{ }

template<typename T>
LinkedList<T>::~LinkedList()
{
    this->delete_all_nodes();
}

// -----

template<typename T>
LinkedList<T>& LinkedList<T>::operator=(const LinkedList<T>& other)
{
    return *this = LinkedList<T>(other);
}

template<typename T>
LinkedList<T>& LinkedList<T>::operator=(LinkedList<T>&& other)
{
    if (this != &other)
    {
        this->delete_all_nodes();
        this->head = other.head;
        this->len  = other.len;
        other.head = nullptr;
        other.len  = 0;
    }

    return *this;
}

// -----

template<typename T>
std::size_t LinkedList<T>::get_len() const
{
    return this->len;
}

// -----

template<typename T>
void LinkedList<T>::push_head(const T& value)
{
    T copy = value;
    this->push_head(std::move(copy));
}

template<typename T>
void LinkedList<T>::push_head(T&& value)
{
    auto new_node = new LinkedListNode<T>;
    new_node->value = value;
    new_node->next  = this->head;
    new_node->prev  = nullptr;

    if (this->head == nullptr)
        this->tail = new_node;
    else
        this->head->prev = new_node;

    this->head = new_node;
    this->len += 1;
}

template<typename T>
void LinkedList<T>::push_tail(const T& value)
{
    T copy = value;
    this->push_tail(std::move(copy));
}

template<typename T>
void LinkedList<T>::push_tail(T&& value)
{
    auto new_node = new LinkedListNode<T>;
    new_node->value = value;
    new_node->next  = nullptr;
    new_node->prev  = this->tail;

    if (this->tail == nullptr)
        this->head = new_node;
    else
        this->tail->next = new_node;

    this->tail = new_node;
    this->len += 1;
}

template<typename T>
void LinkedList<T>::insert_at(std::size_t idx, const T& value)
{
    T copy = value;
}

template<typename T>
void LinkedList<T>::insert_at(std::size_t idx, T&& value)
{
    assert(idx >= 0 && idx <= this->len);

    if (idx == 0)
    {
        this->push_head(value);
        return;
    }

    if (idx == this->len)
    {
        this->push_tail(value);
        return;
    }

    auto prev_node = this->find_at(idx - 1);

    auto new_node = new LinkedListNode<T>{};
    new_node->value = value;
    new_node->prev  = prev_node;
    new_node->next  = prev_node->next;

    if (prev_node->next)
        prev_node->next->prev = new_node;

    prev_node->next = new_node;

    this->len += 1;
}

// -----

template<typename T>
T LinkedList<T>::pop_head()
{
    assert(this->head != nullptr);

    auto node  = this->head;
    this->head = this->head->next;
    this->head->prev = nullptr;

    if (this->len == 1)
        this->tail = nullptr;

    auto value = std::move(node->value);
    delete node;
    this->len -= 1;

    return value;
}

template<typename T>
T LinkedList<T>::pop_tail()
{
    assert(this->head != nullptr);

    auto node  = this->tail;
    this->tail = this->tail->prev;
    this->tail->next = nullptr;

    if (this->len == 1)
        this->head = nullptr;

    auto value = std::move(node->value);
    delete node;
    this->len -= 1;

    return value;
}

template<typename T>
T LinkedList<T>::remove_at(std::size_t idx)
{
    assert(idx >= 0 && idx < this->len);

    if (idx == 0)
        return this->pop_head();

    if (idx == this->len - 1)
        return this->pop_tail();

    auto node = this->find_at(idx);
    node->prev->next = node->next;
    node->next->prev = node->prev;

    const auto value = node->value;
    delete node;
    this->len -= 1;

    return value;
}

// -----

template<typename T>
const T& LinkedList<T>::peek_head() const
{
    assert(this->head != nullptr);
    return this->head->value;
}

template<typename T>
const T& LinkedList<T>::peek_tail() const
{
    assert(this->tail!= nullptr);
    return this->tail->value;
}

template<typename T>
const T& LinkedList<T>::peek_at(std::size_t idx) const
{
    assert(idx >= 0 && idx <= this->len);
    return this->find_at(idx)->value;
}

// -----

template<typename T>
void LinkedList<T>::print() const
{
    std::cout << "----------" << std::endl;
    std::cout << "Head: " << this->head << std::endl;
    std::cout << "Tail: " << this->tail << std::endl;

    auto node = this->head;
    while (node != nullptr)
    {
        std::cout << "Element: "<< node->value << std::endl;
        node = node->next;
    }

    std::cout << "----------" << std::endl;
}

// -----

template<typename T>
LinkedListNode<T>* LinkedList<T>::find_at(std::size_t idx) const
{
    auto node = this->head;
    for (auto i = 0; i < idx; i++)
    {
        node = node->next;
    }

    return node;
}

template<typename T>
void LinkedList<T>::delete_all_nodes()
{
    auto node = this->head;
    while (node != nullptr) {
        auto next = node->next;
        delete node;
        node = next;
    }
}

// ----------------------------------------------

}
