extern "C" int fibonacci(int n) {
    if (n <= 1)
        return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}

extern "C" void _start() {
    volatile int result = fibonacci(1);
    while (1);   // stop execution
}
