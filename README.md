# AutoScheduler

AutoScheduler is a cross-platform, energy-aware scheduling framework for heterogeneous
systems (CPU, GPU, NUMA), implemented in Julia.

It is designed to be safe by default, policy-driven, and explicit about what it can
and cannot optimize.

---

## Overview

AutoScheduler sits between applications and hardware observation layers.
It does not replace runtimes or compilers; it augments scheduling decisions
using real system metrics and explicit policies.

---

## Design Principles

### 1. Non-Intrusive by Default

If a workload is uniform and static scheduling is optimal, AutoScheduler
introduces no measurable overhead.

### 2. Policy-Driven Scheduling

Scheduling decisions are controlled through explicit optimization modes:

- `:energy`
- `:performance`
- `:balanced`

There are no hidden heuristics.

### 3. Heterogeneity as a First-Class Concern

AutoScheduler is evaluated primarily on non-uniform workloads where:
- stragglers exist
- tail latency matters
- deadlines and energy budgets compete

---

## Architecture

### Platform Layer

- System metrics (CPU, memory, load, temperature)
- GPU detection (NVIDIA, AMD, Intel, Apple)
- Process and power monitoring

### Scheduling Core

- Task abstraction (intentionally not exported)
- Resource allocation logic
- Policy hooks for energy and performance tradeoffs

### Algorithms

- Static baselines (FIFO, static partitioning)
- Dynamic load balancing
- DAG-aware scheduling (HEFT-style)
- Deadline- and tail-aware policies

### Live Layer (Optional)

- Online monitoring
- REST API
- WebSocket-based real-time streaming

---

## Benchmarks

AutoScheduler includes benchmarks designed to separate scheduler impact
from system noise.

### Included Workloads

- Monte Carlo (uniform baseline)
- Non-uniform Monte Carlo (tail latency, stragglers)
- ResNet-50 (simulated, scheduler-neutral)
- Video encoding
- DNA sequence alignment
- MapReduce

Metrics reported include:
- Mean and standard deviation
- p95 / p99 tail latency
- Energy consumption (measured or estimated)

---

## What AutoScheduler Is Not

- A compiler
- A kernel optimizer
- A replacement for ML runtimes
- A guarantee of speedup

Uniform workloads often show neutral results by design.

---

## Intended Use Cases

- Systems research
- Energy-aware scheduling experiments
- Heterogeneous runtime evaluation
- Teaching and reproducible benchmarking

---

## Project Status

AutoScheduler is a research-grade library.
Some components are production-stable; others are minimal reference
implementations intended for extension.

---

## Philosophy

Schedulers should not lie.

AutoScheduler treats “no improvement” as a valid and correct outcome
when dynamic scheduling is unnecessary.
