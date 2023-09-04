#pragma once

#include "linked_list.hpp"
#include <functional>
#include <ostream>
#include <queue>
#include <vector>


namespace hell
{

// ----------------------------------------------

template<typename T>
struct BSTreeNode
{
    T value;
    BSTreeNode<T>* left;
    BSTreeNode<T>* right;
};

// ----------------------------------------------

template<typename T>
using FnTraverseValues = const std::function<void(const T&)>&;

template<typename T>
using FnTraverseNodesMut = const std::function<void(BSTreeNode<T>*)>&;

// ----------------------------------------------

template<typename T>
class BSTree
{
private:
    BSTreeNode<T>* root;

public:
    BSTree();
    BSTree(const BSTree& other);
    BSTree(BSTree&& other);
    ~BSTree();

    BSTree<T>& operator=(const BSTree<T>& other);
    BSTree<T>& operator=(BSTree<T>&& other);

    void insert(const T& value);
    void insert(T&& value);
    void remove(const T& value);

    void rotate_left();
    void rotate_right();

    void traverse_level_order(FnTraverseValues<T> func) const;
    void traverse_pre_order  (FnTraverseValues<T> func) const;
    void traverse_in_order   (FnTraverseValues<T> func) const;
    void traverse_post_order (FnTraverseValues<T> func) const;

private:
    BSTreeNode<T>* find_parent_node(T& value) const;

    static BSTreeNode<T>* remove_recursive(BSTreeNode<T>* root, const T& value);
    static BSTreeNode<T>* find_node_min_recursive(BSTreeNode<T>* root);

    static void traverse_values_pre_order_recursive (BSTreeNode<T>* node, FnTraverseValues<T> func);
    static void traverse_values_in_order_recursive  (BSTreeNode<T>* node, FnTraverseValues<T> func);
    static void traverse_values_post_order_recursive(BSTreeNode<T>* node, FnTraverseValues<T> func);

    static void traverse_nodes_pre_order_recursive (BSTreeNode<T>* node, FnTraverseNodesMut<T> func);
    static void traverse_nodes_in_order_recursive  (BSTreeNode<T>* node, FnTraverseNodesMut<T> func);
    static void traverse_nodes_post_order_recursive(BSTreeNode<T>* node, FnTraverseNodesMut<T> func);
};

// -----

template<typename T>
BSTree<T>::BSTree()
    : root(nullptr)
{}

template<typename T>
BSTree<T>::BSTree(const BSTree<T>& other)
    : root(nullptr)
{
    if (other.root == nullptr)
        return;

    other.traverse_level_order([this] (T value) mutable {
        this->insert(value);
    });
}

template<typename T>
BSTree<T>::BSTree(BSTree<T>&& other)
    : root(std::exchange(other.root, nullptr))
{ }

template<typename T>
BSTree<T>::~BSTree()
{
    if (this->root == nullptr)
        return;

    BSTree<T>::traverse_nodes_post_order_recursive(this->root, [](BSTreeNode<T>* node) {
        delete node;
    });

    this->root = nullptr;
}

// -----

template<typename T>
BSTree<T>& BSTree<T>::operator=(const BSTree<T>& other)
{
    return *this = BSTree<T>(other);
}

template<typename T>
BSTree<T>& BSTree<T>::operator=(BSTree<T>&& other)
{
    if (this != &other)
    {
        this->root = other.root;
        other.root = nullptr;
    }

    return *this;
}

// -----

template<typename T>
void BSTree<T>::insert(const T& value)
{
    T copy = value;
    this->insert(std::move(copy));
}

template<typename T>
void BSTree<T>::insert(T&& value)
{
    auto new_node = new BSTreeNode<T> {};
    new_node->value = value;

    if (this->root == nullptr)
    {
        this->root = new_node;
        return;
    }

    auto node = this->root;
    while (node != nullptr)
    {
        if (value < node->value)
        {
            if (node->left == nullptr)
            {
                node->left = new_node;
                return;
            }

            node = node->left;
        }
        else if (value > node->value)
        {
            if (node->right == nullptr)
            {
                node->right = new_node;
                return;
            }

            node = node->right;
        }
        else
        {
            // TODO(lm): error handling
            std::cout << "trying to push duplicate node '" << node->value << "' - skipping ..." << std::endl;
            return;
        }
    }

    // TODO(lm): error handling
    std::cout << "failed to insert new node '" << node->value << "'" << std::endl;
}

template<typename T>
void BSTree<T>::remove(const T& value)
{
    auto _ = BSTree<T>::remove_recursive(this->root, value);
}

// -----

template<typename T>
void BSTree<T>::rotate_left()
{
    if ((this->root == nullptr) || (this->root->right == nullptr))
        return;

    auto child = this->root->right;
    this->root->right = child->left;
    child->left = this->root;
    this->root = child;
}

template<typename T>
void BSTree<T>::rotate_right()
{
    if ((this->root == nullptr) || (this->root->left == nullptr))
        return;

    auto child = this->root->left;
    this->root->left = child->right;
    child->right = this->root;
    this->root = child;
}

// -----

template<typename T>
void BSTree<T>::traverse_level_order(FnTraverseValues<T> func) const
{
    if (this->root == nullptr)
        return;

    // TODO(lm): implement custom queue
    auto queue = std::queue<BSTreeNode<T>*> {};

    queue.push(this->root);

    while (!queue.empty())
    {
        auto node = queue.front();
        if (node->left)
            queue.push(node->left);
        if (node->right)
            queue.push(node->right);

        func(node->value);
        queue.pop();
    }
}

template<typename T>
void BSTree<T>::traverse_pre_order(FnTraverseValues<T> func) const
{
    if (this->root == nullptr)
        return;

    BSTree<T>::traverse_values_pre_order_recursive(this->root, func);
}

template<typename T>
void BSTree<T>::traverse_in_order(FnTraverseValues<T> func) const
{
    if (this->root == nullptr)
        return;

    BSTree<T>::traverse_values_in_order_recursive(this->root, func);
}

template<typename T>
void BSTree<T>::traverse_post_order(FnTraverseValues<T> func) const
{
    if (this->root == nullptr)
        return;

    BSTree<T>::traverse_values_post_order_recursive(this->root, func);
}

// -----

template<typename T>
BSTreeNode<T>* BSTree<T>::find_parent_node(T& value) const
{
    return nullptr;
}

template<typename T>
void BSTree<T>::traverse_values_pre_order_recursive(BSTreeNode<T>* node, FnTraverseValues<T> func)
{
    func(node->value);

    if (node->left != nullptr)
        BSTree<T>::traverse_values_pre_order_recursive(node->left, func);
    if (node->right != nullptr)
        BSTree<T>::traverse_values_pre_order_recursive(node->right, func);
}

template<typename T>
void BSTree<T>::traverse_values_in_order_recursive(BSTreeNode<T>* node, FnTraverseValues<T> func)
{
    if (node->left != nullptr)
        BSTree<T>::traverse_values_in_order_recursive(node->left, func);

    func(node->value);

    if (node->right != nullptr)
        BSTree<T>::traverse_values_in_order_recursive(node->right, func);
}

template<typename T>
void BSTree<T>::traverse_values_post_order_recursive(BSTreeNode<T>* node, FnTraverseValues<T> func)
{
    if (node->left != nullptr)
        BSTree<T>::traverse_values_post_order_recursive(node->left, func);
    if (node->right != nullptr)
        BSTree<T>::traverse_values_post_order_recursive(node->right, func);

    func(node->value);
}

// -----

template<typename T>
BSTreeNode<T>* BSTree<T>::remove_recursive(BSTreeNode<T>* root, const T& value)
{
    if (root == nullptr)
        return root;

    if (value < root->value)
    {
        root->left = BSTree<T>::remove_recursive(root->left, value);
    }
    else if (value > root->value)
    {
        root->right = BSTree<T>::remove_recursive(root->right, value);
    }
    else
    {
        // case: no child
        if ((root->left == nullptr) && (root->right == nullptr))
        {
            delete root;
            root = nullptr;
        }
        // on child on the right
        else if (root->left == nullptr)
        {
            auto temp = root;
            root->right;
            delete temp;
        }
        // on child on the left
        else if (root->right == nullptr)
        {
            auto temp = root;
            root->left;
            delete temp;
        }
        // two children
        else
        {
            auto min_node = BSTree<T>::find_node_min_recursive(root->right);
            root->value   = min_node->value;
            root->right   = BSTree<T>::remove_recursive(root->right, root->value);
        }
    }

    return root;
}

template<typename T>
BSTreeNode<T>* BSTree<T>::find_node_min_recursive(BSTreeNode<T>* root)
{
    if (root->left == nullptr)
        return root;

    return BSTree<T>::find_node_min_recursive(root->left);
}


// -----

template<typename T>
void BSTree<T>::traverse_nodes_pre_order_recursive(BSTreeNode<T>* node, FnTraverseNodesMut<T> func)
{
    func(node);

    if (node->left != nullptr)
        BSTree<T>::traverse_nodes_post_order_recursive(node->left, func);
    if (node->right != nullptr)
        BSTree<T>::traverse_nodes_post_order_recursive(node->right, func);
}

template<typename T>
void BSTree<T>::traverse_nodes_in_order_recursive(BSTreeNode<T>* node, FnTraverseNodesMut<T> func)
{
    if (node->left != nullptr)
        BSTree<T>::traverse_nodes_post_order_recursive(node->left, func);

    func(node);

    if (node->right != nullptr)
        BSTree<T>::traverse_nodes_post_order_recursive(node->right, func);
}

template<typename T>
void BSTree<T>::traverse_nodes_post_order_recursive(BSTreeNode<T>* node, FnTraverseNodesMut<T> func)
{
    if (node->left != nullptr)
        BSTree<T>::traverse_nodes_post_order_recursive(node->left, func);
    if (node->right != nullptr)
        BSTree<T>::traverse_nodes_post_order_recursive(node->right, func);

    func(node);
}

// ----------------------------------------------

}
