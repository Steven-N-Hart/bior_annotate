# bior_annotate
### Setup/Install
```
$ docker build -t stevenhart/bior_annotate:latest .
```
### Launch
```
$ docker run -it -v /path/to/local/Data:/home/Data stevenhart/bior_annotate:latest
```
> Make sure to change "/path/to/local/Data" to your respective directory containing the VCF