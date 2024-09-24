# class CQL::Error

`Exception` < `Reference` < `Object`

Error class This class represents an error in the CQL library It provides a message describing the error

**Example** Raising an error

```crystal
raise CQL::Error.new("Something went wrong")
```

## Constructors

### def new`(message : String)`
