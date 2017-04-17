%option noyywrap nodefault yylineno
%x LINE
%x FUNCTION
%x KERNAL
%{
  //这个部分是对中间文件的第一次过滤，主要保留用户所写的东西，还有一些关键变量的名字，关键变量从何而来主要取决于
  //用户是怎么配置的，这个文件会由java外部程序生成。当然我们会根据CUDA现有的接口原型写出所有伪CUDA接口
  //是的关于GPU的函数并不是真正运行
  //在这一步的最后我们要得出所有的核函数的名字，为第二次去除CUDA痕迹的工作做准备。此外这个文件还要整理一下整个
  //中间文件的格式，方便下一步处理。
  //同时在这个文件中，我们还要进行格式整理
  extern int yylineno;
  int flag;
  char* headFileName[100];
  int fileCount;
  //这个变量是上一次匹配到需要的行号，我们把行号记录下来，然后读取这一行的下一行代码。
  int lastline;
  //当在KERNAL状态下接近内核函数名称的时候我们这个变量会被置为1
  int nearKernal;
%}

%%
^"# "[0-9]+ {
  //代码块负责找到一个line，然后将
  //printf("找到了一行我们需要的注释在第%d行\n", yylineno);
  //不管之前发生什么，进入line之前flag都要是0
  flag = 0;
  BEGIN LINE;
}

<FUNCTION>"cudaConfigureCall("  {
  //进入这里说明在后面将会进入核函数，我们要找到核函数的名称，为接下来的扫描做准备
  ECHO;
  nearKernal = 0;
  BEGIN KERNAL;
}

<KERNAL>"? (void)0 : (" {
  //进入这里说明紧接着的就是内核函数了
  ECHO;
  nearKernal = 1;
}

<KERNAL>[A-Za-z]{1}[A-Za-z0-9_]*/")"  {
  if(nearKernal == 1){
    printf("检测到核函数%s在第%d行\n",yytext,yylineno);
    ECHO;
    BEGIN FUNCTION;
  }else{
    ECHO;
  }
}

<KERNAL>.|\n {
  ECHO;
}

<FUNCTION>("{"|"}"|";"|"\042"|\"|"("|")")((" ")|[\t])*/([^\n])  {
    //这个代码块就是用来整理格式的，如果碰到一个之后没有回车的;{}，那就帮他们加一个回车
    //因为我们后来发现因为关键变量会先匹配之前的一位字符，有时候引号就会和之后的关键变脸一起匹配，所以需要在引号后面添加回车
    //同时还有括号
    fprintf(yyout,"%s\n",yytext);
}

<FUNCTION>^"# "[0-9]+ {
  //printf("在匹配函数的过程当中重新匹配到了注释\n");
  //代码块负责找到一个line，然后将
  //printf("找到了一行我们需要的注释在第%d行\n", yylineno);
  //printf("进入LINE状态\n");
  flag = 0;
  BEGIN LINE;
}

<FUNCTION>^"#"  {
  //printf("匹配到了不需要的东西\n");
  //printf("进入INITIAL状态\n");
  BEGIN INITIAL;
}


<FUNCTION>. {
  if(lastline <= yylineno -1){
    //printf("这里需要打印店东西\n");
    ECHO;
  }
}

<FUNCTION>^\n {
  ECHO;
}

<FUNCTION>\n/"#"  {
  BEGIN INITIAL;
}


<FUNCTION>\n  {
  //printf("检测到回车lastline=%d,yylineno=%d\n",lastline,yylineno);
  ECHO;
}



<LINE>"/usr/include"|"/usr/lib"|"/usr/local"  {
  //我们这里以Linux为例，去除C语言的标准库和CUDA库的
  //printf("匹配到了标准库和CUDA库\n");
  BEGIN INITIAL;
}

<LINE>[A-Za-z0-9_\.]+".h"/\042  {
  //这里获取我们能够匹配到的头文件
  //printf("这里匹配到一个头文件%s在第%d行\n",yytext,yylineno);
  lastline = yylineno;
  //printf("进入FUNCTION状态\n");
  BEGIN FUNCTION;
}

<LINE>[A-Za-z0-9_\.]+".cu"/\042 {
  //这里获取我们能够匹配到的cu文件
  if(yylineno > 100)
  {
    //printf("这里匹配到一个cu文件%s\n在第%d行\n",yytext,yylineno);
    lastline = yylineno;
    //printf("进入FUNCTION状态\n");
    BEGIN FUNCTION;
  }

}

<LINE>[A-Za-z0-9_\.]+".c"/\042 {
  //这里获取我们能够匹配到的cu文件
  //printf("这里匹配到一个c文件%s\n在第%d行\n",yytext,yylineno);

  if(strcmp(yytext,"Test2.cudafe1.stub.c")==0||strcmp(yytext,"Test2.fatbin.c")==0){
    //printf("发现了不需要的文件\n");
  }else{
    lastline = yylineno;
    //printf("进入FUNCTION状态\n");
    BEGIN FUNCTION;
  }

}


<LINE>\042  {
  //printf("正在尝试是不是匹配上的引号\n");
  //通过判断经过的引号的个数来判断是不是应该退出LINE模式
  flag++;
  if (flag == 2){
    BEGIN INITIAL;
  }
}

<LINE>.|\n {}


. {}
\n  {}
%%
int main(int argc, char *argv[]){
  yylineno = 1;
  flag = 0;
  fileCount = 0;
  /*首先把输入和输出文件规定好*/
  if(argc > 2){
    if(!(yyin = fopen(argv[1],"r"))){
      perror(argv[1]);
      return 1;
    }
    if(!(yyout = fopen(argv[2],"w"))){
      perror(argv[2]);
      return 1;
    }
  }

  printf("输入输出文件定位完毕，开始进行分析\n");

  yylex();
}
