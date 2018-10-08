import java.io.DataOutputStream;
import java.io.FileOutputStream;
public class javawriteOpened extends Thread
{
    java.io.DataOutputStream stream;
    short[] shortData;
    boolean closeStream;
    public javawriteOpened(java.io.DataOutputStream fID, short[] data)
    {
        this(fID, data, false);
    }
    public javawriteOpened(java.io.DataOutputStream fID, short[] data, boolean cl)
    {
        this.stream = fID;
        this.shortData = data;
        this.closeStream = cl;
    }
    
    @Override
    public void run()
    {
        try
        {
            for (int i=0; i < shortData.length; i++)
            {
                stream.writeShort(shortData[i]);
            }
            if (closeStream)
              stream.close();
        } catch (Exception ex) {
            System.out.println(ex.toString());
        }
    }
}