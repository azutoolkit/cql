---
title: "Cql::Error"
---

# class Cql::Error

`Exception` < `Reference` < `Object`

Error class
This class represents an error in the Cql library
It provides a message describing the error

**Example** Raising an error

```crystal
raise Cql::Error.new("Something went wrong")
```

details Table of Contents
[[toc]]

## Constructors

### def new`(message : String)`
