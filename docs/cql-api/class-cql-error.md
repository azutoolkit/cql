# class Cql::Error

`Exception` < `Reference` < `Object`

Error class This class represents an error in the Cql library It provides a message describing the error

**Example** Raising an error

```crystal
raise Cql::Error.new("Something went wrong")
```

## Constructors

### def new`(message : String)`