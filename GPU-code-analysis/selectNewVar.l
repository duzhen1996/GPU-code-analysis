%option noyywrap nodefault yylineno

%{
  extern int yylineno;
  //我们需要一个数组来存所有的关建行的行号，所有的行号按照从小到大的顺序排列
  int keyLineArray[]={1,2,5};
  int keyLineArraySize=3;//上面的那个数组的大小
  int keyLineIndex=0;//上面的那个的当前索引。
%}

%%
\n {
  printf("匹配到回车，在第%d行",yylineno);
  //查看这个行号是不是关建行号

}

. {
  //一般情况下的全部忽略
}

%%
int main(int argc, char *argv[]){
  yylineno = 1;

  /*首先把输入和输出文件规定好*/
  if(argc > 1){
    if(!(yyin = fopen(argv[1],"r"))){
      perror(argv[1]);
      return 1;
    }
    if(!(yyout = fopen(argv[2],"w"))){
      //这里将会返回一个基本可编译的C语言文件
      perror(argv[2]);
      return 1;
    }
  }

  printf("输入输出文件定位完毕，开始进行分析\n");

  yylex();
}
