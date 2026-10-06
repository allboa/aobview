# aobview: View Spatial Data in Its Own Coordinate Reference System

A convenience front end for 'allonboard' map scenes: 'view(x)' draws
spatial objects in a self-contained HTML page, in their own coordinate
reference system or a polar view chosen for them, through the lean core
package 'aobcore'. Vector data are read through 'wk' (any geometry it
can handle, or a data frame with such a column, 'sf' included), from
Arrow streams and tables (a 'duckdb' result, a GDAL layer) and from
'gdalraster' feature sets, and reprojected with 'PROJ'. This is an early
skeleton; the package name is a placeholder.

## See also

Useful links:

- <https://allboa.github.io/aobview/>

- <https://github.com/allboa/aobview>

- Report bugs at <https://github.com/allboa/aobview/issues>

## Author

**Maintainer**: Michael Sumner <mdsumner@gmail.com>

Authors:

- Michael Sumner <mdsumner@gmail.com>
