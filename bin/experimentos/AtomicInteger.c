
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>


typedef struct {
    int value;
    pthread_mutex_t lock;
} AtomicInteger;

void atomicIntegerInit(AtomicInteger* atomicInt, int initialValue) {
    atomicInt->value = initialValue;
    pthread_mutex_init(&atomicInt->lock, NULL);
}

int atomicIntegerGet(AtomicInteger* atomicInt) {
    int result;
    pthread_mutex_lock(&atomicInt->lock);
    result = atomicInt->value;
    pthread_mutex_unlock(&atomicInt->lock);
    return result;
}

void atomicIntegerSet(AtomicInteger* atomicInt, int newValue) {
    pthread_mutex_lock(&atomicInt->lock);
    atomicInt->value = newValue;
    pthread_mutex_unlock(&atomicInt->lock);
}

int atomicIntegerIncrementAndGet(AtomicInteger* atomicInt) {
    int result;
    pthread_mutex_lock(&atomicInt->lock);
    atomicInt->value++;
    result = atomicInt->value;
    pthread_mutex_unlock(&atomicInt->lock);
    return result;
}

void* incrementThread(void* arg) {
    AtomicInteger* counter = (AtomicInteger*)arg;

    for (int i = 0; i < 10000; ++i) {
        atomicIntegerIncrementAndGet(counter);
    }

    return NULL;
}

int main() {
    AtomicInteger myAtomicInt;
    atomicIntegerInit(&myAtomicInt, 0);

    // Criação de threads
    pthread_t thread1, thread2;

    pthread_create(&thread1, NULL, incrementThread, &myAtomicInt);
    pthread_create(&thread2, NULL, incrementThread, &myAtomicInt);

    // Espera que as threads terminem
    pthread_join(thread1, NULL);
    pthread_join(thread2, NULL);

    // Exibe o resultado
    printf("Final value: %d\n", atomicIntegerGet(&myAtomicInt));

    return 0;
}





