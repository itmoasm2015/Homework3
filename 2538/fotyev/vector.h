#ifndef VECTOR_H
#define VECTOR_H

#include <type_traits>
#include <memory>
#include <vector>
#include <algorithm>
#include <cassert>
#include <cstring>

template <typename T>
class vector
{
        static_assert(std::is_pod<T>::value, "POD only!");

private:
        enum
        {
                SMALL_SIZE = 256 / sizeof(T)
        };
        std::array<T, SMALL_SIZE> small;
        std::size_t cur_size = 0;
        std::shared_ptr<std::vector<T> > big;

public:
        std::size_t size() const { return cur_size; }
        bool empty() const { return cur_size == 0; }
        
        T& back() { return (*this)[cur_size-1]; }
        T& front() { return (*this)[0]; }


        const T& get(std::size_t idx) const { return (*this)[idx]; }
        void set(std::size_t idx, const T& obj) { (*this)[idx] = obj; }

        const T& at(std::size_t idx) const { return (*this)[idx]; }
        T& at(std::size_t idx) { return (*this)[idx]; }


        T& operator[](std::size_t idx)
        {
                modify();
                assert(idx < cur_size);
                if(cur_size <= SMALL_SIZE)
                {
                        return small[idx];
                }
                assert(big.use_count());
                return big->at(idx);
        }
        
        const T& operator[](std::size_t idx) const
        {
                assert(idx < cur_size);
                if(cur_size <= SMALL_SIZE)
                {
                        return small[idx];
                }
                assert(big.use_count());
                return big->at(idx);
        }

        void push_back(const T& obj)
        {
                #if 1
                modify();
                if(cur_size < SMALL_SIZE)
                {
                        assert(!big.use_count());
                        small[cur_size++] = obj;
                        return;
                }
                if(cur_size == SMALL_SIZE)
                {
                        // enlarge
                        assert(!big.use_count());
                        big = std::make_shared<std::vector<T> >();
                        big->reserve(cur_size + 1);
                        big->assign(small.begin(), small.begin() + cur_size);
                }
                assert(big.use_count());
                big->push_back(obj);
                ++cur_size;
                #else
                insert(end(), obj);
                #endif
        }

        void pop_back()
        {
                assert(!empty());
                #if 1
                modify();
                if(cur_size <= SMALL_SIZE)
                {
                        assert(!big.use_count());
                        cur_size--;
                        return;
                }
                assert(big.use_count());
                big->pop_back();

                if(cur_size == SMALL_SIZE + 1)
                {
                        std::copy(big->begin(), big->end(), small.begin());
                        big.reset();
                }
                --cur_size;
                #else
                erase(end() - 1);
                #endif
        }


        void reserve(std::size_t newcap)
        {
                if(cur_size <= SMALL_SIZE)
                        return;
                assert(big.use_count());
                if(cur_size >= newcap)
                        return;
                // modify() ?
                big->reserve(newcap);
        }


        // copying

        vector<T>& operator=(const vector<T>& rhs)
        {
                cur_size = rhs.cur_size;
                big.reset();
                if(rhs.cur_size <= SMALL_SIZE)
                {
                        // small copy
                        std::copy(rhs.small.begin(), rhs.small.begin() + rhs.cur_size, small.begin());
                        //memcpy(&small[0], rhs.small.data(), rhs.cur_size * sizeof(T));
                }
                else
                        big = rhs.big;
                return *this;
        }
        vector<T>& operator=(vector<T>&& rhs)
        {
                cur_size = rhs.cur_size;
                if(rhs.cur_size <= SMALL_SIZE)
                {
                        std::copy(rhs.small.begin(), rhs.small.begin() + rhs.cur_size, small.begin());
                        //memcpy(&small[0], rhs.small.data(), rhs.cur_size * sizeof(T));
                }
                big.reset();
                big.swap(rhs.big);
                rhs.cur_size = 0;
                return *this;
        }

        // ctor
        vector<T>() {}
        
        vector<T>(const vector<T>& v)
        {
                *this = v;
        }
        
        vector<T>(vector<T>&& v)
        {
                *this = std::move(v);
        }

        
public: //iterators
        typedef T * iterator;
        typedef const T * const_iterator;

        iterator begin() { modify(); return (cur_size <= SMALL_SIZE) ? &small[0] : &(big->at(0)); }
        const_iterator cbegin() const { return (cur_size <= SMALL_SIZE) ? small.data() : big->data(); }
        const_iterator begin() const { return cbegin(); }

        iterator end() { modify(); return (cur_size <= SMALL_SIZE) ? (&small[0] + cur_size) : (&(big->at(0)) + cur_size); }
        const_iterator cend() const { return (cur_size <= SMALL_SIZE) ? (small.data() + cur_size) : (big->data() + cur_size); }
        const_iterator end() const { return cend(); }

public:

        void insert(const_iterator pos, const T& obj)
        {
                return insert(pos, 1, obj);
        }

        void insert(const_iterator pos, std::size_t n, const T& obj)
        {
                if(n == 0)
                        return;
                modify();
                std::size_t idx = pos - cbegin();
                if(cur_size <= SMALL_SIZE)
                {
                        if(cur_size + n <= SMALL_SIZE)
                        {
                                for(int i = int(cur_size) - 1; i >= int(idx); i--)
                                        small[i + n] = small[i];
                                
                                for(std::size_t i = 0; i < n; i++)
                                        small[idx + i] = obj;
                                cur_size += n;
                                return;
                        }
                        else
                        {
                                // switch to big
                                assert(!big.use_count());
                                big = std::make_shared<std::vector<T> >();
                                big->reserve(cur_size + n);
                                big->assign(small.begin(), small.begin() + cur_size);
                        }
                }
                assert(big.use_count() == 1);
                big->insert(big->begin() + idx, n, obj);
                assert(big->size() == n + cur_size);
                cur_size += n;
        }
        
        void erase(const_iterator pos)
        {
                return erase(pos, pos + 1);
        }
        
        void erase(const_iterator first, const_iterator last)
        {
                std::size_t idx = first - cbegin();
                std::size_t n = last - first;
                assert(idx + n <= cur_size);
                if(n == 0)
                        return;
                modify();
                if(cur_size <= SMALL_SIZE)
                {
                        for(std::size_t i = idx + n; i < cur_size; i++)
                                small[i - n] = small[i];
                        cur_size -= n;
                        return;
                }
                assert(big.use_count() == 1);
                big->erase(big->begin() + idx, big->begin() + idx + n);
                assert(big->size() == cur_size - n);
                cur_size = big->size();
                if(cur_size <= SMALL_SIZE)
                {
                        std::copy(big->begin(), big->end(), small.begin());
                        //memcpy(&small[0], big->data(), cur_size * sizeof(T));
                        big.reset();
                }
        }

        void resize(std::size_t n, const T& obj = T())
        {
                if(n > cur_size)
                        insert(end(), n - cur_size, obj);
                else if(n < cur_size)
                        erase(begin() + n, end());
                assert(cur_size == n);
        }


public: // compare

        bool operator==(const vector<T>& rhs) const
        {
                if(cur_size != rhs.cur_size)
                        return false;
                if(cur_size <= SMALL_SIZE)
                        return std::equal(cbegin(), cend(), rhs.cbegin());
                else
                        return (big == rhs.big || *big == *rhs.big);
        }
        

        bool operator!=(const vector<T>& rhs) const { return !(*this == rhs); }



private:
        // call before modifying vector
        void modify() // copy
        {
                if(cur_size <= SMALL_SIZE) // ok
                        return;
                if(big.use_count() == 1) // big is owned by us
                        return;
                assert(big.use_count() > 1);
                // copy
                big = std::make_shared<std::vector<T> >(*big);
                assert(big.use_count() == 1);
        }

};

#endif
