%option noyywrap nodefault yylineno
%{
  //这个文件我们要做的就是登记所有的CUDA变量的行，我们已经获取了现在的CUDA变量的名称、还有所在的嵌套等级以及其他
  //所以我们应该先把这些CUDA变量的名称生成一个命名模式，当匹配到这个命名模式的时候我们设立三个数组，这三个数组每一位都是一一对应的
  //第一个数组就是这个变量名，第二个数组就是一个变量名所对应的braceId，第三个数组就是这个变量名所对应的nesting嵌套等级
  //整个的过程如下，首先我们通过我们提前设立好的命名模式来获得这个变量名的匹配
  //然后我们使用匹配到的变量名去遍历第一个数组，因为第一个数组中的元素有可能是重复的，所以我们需要在匹配到第一个数组之后去匹配第二个数组
  //的对应项，如果我们在匹配之后发现这个变量的braceid和第二个数组中数字是吻合的，那么我们就去匹配第三个数组中的nesting，如果发现
  //在第三个数组中的nesting小于等于我们匹配到的变量的nesting那我们就可以把这个变量出现的这一行也划到要删除的范畴里面去。
  extern int yylineno;


  //这里我们依旧需要加入表明小括号嵌套和大括号嵌套的东西，但是我们还需要一组变量来区分不同的小括号和大括号
  int nesting;
  int smallnesting;
  //一组变量区分不同的大括号和不同的小括号,二元组（braceId,nesting）可以唯一标识一个大括号题，小括号也是一样的道理
  int braceId;
  int parenthesesId;

  //还有一个变量记录了上一个记录的“要求被删除的行的行号”
  int lastDeleteLine;
  //这个数组存储了所有要删除的行号
  int lineCount[10000];
  //这个变量存着数组的下一个空位的索引
  int lineCountIndex;
  //这个函数用来向数组中添加一个行号，还要添加一个这个变量所在的嵌套id和代码块嵌套级数，我们
  //的删除是有一个原则的，那就是只删除嵌套id一样、并且nesting比这个变量出现的位置要大的同名参数
  //这样子我们就可以尽可能防止误删
  void recordLineNumber(int yylineno);


  char* varName[] = {"_m_cudaStat","_m_cudaStat","_m_cudaStat"};
  int varNesting[] = {0,0,0};
  int varBranceId[] = {0,1,2};
  //这个变量存着三个数组的大小，应该是一致的
  int size = 3;
%}

CUDAvar ("_m_cudaStat")

%%
{CUDAvar} {
  printf("匹配到CUDA相关变量在第%d行,BranceId = %d\n",yylineno,braceId);
  //这里匹配到了与CUDA直接相关的变量，我们要进行多个维度的对比
  //为了保证维度规范的统一性，我们保留了RemoveCudaVar文件中的所有关于大括号嵌套和小括号嵌套的工作
  //我们可以可以按理来说可以获取到yytext，nesting、smallnesting等内容进行我们需要的比较
  //虽然这种方式还是无法覆盖所有的生命周期的情况，但是还是做了“尽可能”的考虑
  for(int i = 0; i < size;i++){
    if(strcmp(yytext,varName[i])==0){
      //如果发现是这个变量，那就看看braceId
      if(braceId==varBranceId[i]){
        //如果发现这个也是相等的，就比较nesting
        if(nesting >= varNesting[i]){
          //这个时候我们就需要把这个记录到要删除的行中，并且终止这个循环
          recordLineNumber(yylineno);
          break;
        }
      }
    }
  }
}

"{" {
  //接下来会有一系列在普通模式下对于smallnesting、nesting、parenthesesId、BranceId的修改
  if(nesting == 0){
    braceId++;
  }
  nesting++;
}

"(" {
  if(smallnesting == 0){
    parenthesesId++;
  }
  smallnesting++;
}

")" {
  smallnesting--;
}

"}"  {
  nesting--;
}

.|\n  {
}
%%
void recordLineNumber(int yylineno){
  if(yylineno > lastDeleteLine){
    printf("正在记录要删除的东西\n");
    lineCount[lineCountIndex] = yylineno;
    lineCountIndex++;
    lastDeleteLine = yylineno;
  }
}
int main(int argc, char *argv[]){
  yylineno = 1;
  parenthesesId = 0;
  braceId = 0;
  /*首先把输入和输出文件规定好*/
  if(argc >= 1){
    if(!(yyin = fopen(argv[1],"r"))){
      perror(argv[1]);
      return 1;
    }
  }

  printf("输入输出文件定位完毕，开始进行分析\n");


  yylex();

  printf("\n");
  for(int i = 0; i < lineCountIndex; i++){
    printf("%d,",lineCount[i]);
  }
  printf("\n");

}
