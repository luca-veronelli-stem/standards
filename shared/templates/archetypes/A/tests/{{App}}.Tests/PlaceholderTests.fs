module Stem.{{App}}.Tests.PlaceholderTests

open Xunit
open Stem.{{App}}.Core

[<Fact>]
let ``marker is alive`` () =
    Assert.Equal("alive", Placeholder.Marker)
